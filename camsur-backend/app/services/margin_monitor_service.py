"""
Dynamic per-tool margin circuit breaker.

Recomputes realized margin per tool over a trailing window from REAL data
(actual provider cost recorded on `generations.provider_cost_usd`, actual
purchase revenue from `credit_purchases`) and trips the existing
`tools.is_active` kill switch if a tool is losing real money. Never
re-enables a tool automatically — see docs/COST_CONTROLS.md.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import ROUND_CEILING, Decimal

from supabase import Client

from app.config import Settings
from app.core.logging import get_logger

logger = get_logger(__name__)

DEFAULT_MIN_GROSS_MARGIN_BPS = 2000


@dataclass(frozen=True)
class MarginSnapshot:
    tool_slug: str
    window_days: int
    window_start: datetime
    window_end: datetime
    generations_count: int
    generations_with_cost_count: int
    net_credits: int
    effective_usd_per_credit: Decimal
    revenue_usd: Decimal
    provider_cost_usd: Decimal
    margin_usd: Decimal
    suggested_credit_cost: int | None
    action_taken: str


class MarginMonitorService:
    def __init__(self, db: Client, settings: Settings):
        self.db = db
        self.settings = settings

    def evaluate(self, window_days: int | None = None) -> list[MarginSnapshot]:
        """Pure computation — no DB writes, no enforcement. Used by reports."""
        window_days = window_days or self.settings.margin_monitor_window_days
        window_end = datetime.now(timezone.utc)
        window_start = window_end - timedelta(days=window_days)

        effective_rate = self._effective_usd_per_credit(window_start)
        min_margin_bps = self._min_gross_margin_bps()

        tools = self.db.table("tools").select("slug,is_active").execute().data or []

        return [
            self._evaluate_tool(
                tool["slug"],
                is_active=bool(tool.get("is_active")),
                window_days=window_days,
                window_start=window_start,
                window_end=window_end,
                effective_rate=effective_rate,
                min_margin_bps=min_margin_bps,
            )
            for tool in tools
        ]

    def recompute_and_enforce(self, window_days: int | None = None) -> list[MarginSnapshot]:
        """Computes margin snapshots, persists an audit row for each, and trips
        the kill switch for any tool whose realized margin went negative."""
        snapshots = self.evaluate(window_days)
        for snapshot in snapshots:
            self._persist_snapshot(snapshot)
            if snapshot.action_taken == "disabled":
                self._disable_tool(snapshot.tool_slug)
        return snapshots

    def _evaluate_tool(
        self,
        tool_slug: str,
        *,
        is_active: bool,
        window_days: int,
        window_start: datetime,
        window_end: datetime,
        effective_rate: Decimal,
        min_margin_bps: int,
    ) -> MarginSnapshot:
        gens = (
            self.db.table("generations")
            .select("provider_cost_usd")
            .eq("tool_slug", tool_slug)
            .gte("created_at", window_start.isoformat())
            .execute()
            .data
            or []
        )
        generations_count = len(gens)
        cost_values = [
            Decimal(str(g["provider_cost_usd"]))
            for g in gens
            if g.get("provider_cost_usd") is not None
        ]
        generations_with_cost_count = len(cost_values)
        provider_cost_usd = sum(cost_values, Decimal("0"))

        txs = (
            self.db.table("credit_transactions")
            .select("amount,type")
            .eq("tool_slug", tool_slug)
            .gte("created_at", window_start.isoformat())
            .execute()
            .data
            or []
        )
        spend = sum(-int(t["amount"]) for t in txs if t["type"] == "spend" and int(t["amount"]) < 0)
        refund = sum(int(t["amount"]) for t in txs if t["type"] == "refund" and int(t["amount"]) > 0)
        net_credits = spend - refund

        revenue_usd = (Decimal(net_credits) * effective_rate).quantize(Decimal("0.0001"))
        margin_usd = revenue_usd - provider_cost_usd

        suggested_credit_cost = None
        if generations_with_cost_count > 0 and effective_rate > 0:
            avg_cost = provider_cost_usd / generations_with_cost_count
            required_usd = avg_cost * (Decimal(10_000 + min_margin_bps) / Decimal(10_000))
            suggested_credit_cost = int(
                (required_usd / effective_rate).to_integral_value(rounding=ROUND_CEILING)
            )

        if not is_active:
            action = "already_disabled"
        elif generations_with_cost_count < self.settings.margin_monitor_min_samples:
            action = "insufficient_samples"
        elif margin_usd < 0:
            action = "disabled"
        else:
            action = "none"

        return MarginSnapshot(
            tool_slug=tool_slug,
            window_days=window_days,
            window_start=window_start,
            window_end=window_end,
            generations_count=generations_count,
            generations_with_cost_count=generations_with_cost_count,
            net_credits=net_credits,
            effective_usd_per_credit=effective_rate,
            revenue_usd=revenue_usd,
            provider_cost_usd=provider_cost_usd,
            margin_usd=margin_usd,
            suggested_credit_cost=suggested_credit_cost,
            action_taken=action,
        )

    def _effective_usd_per_credit(self, window_start: datetime) -> Decimal:
        """Blended real $/credit from actually completed purchases (never assumed)."""
        purchases = (
            self.db.table("credit_purchases")
            .select("price_amount_cents,credits")
            .eq("status", "completed")
            .gte("created_at", window_start.isoformat())
            .execute()
            .data
            or []
        )
        if not purchases:
            # Widen to all-time completed purchases before falling back further.
            purchases = (
                self.db.table("credit_purchases")
                .select("price_amount_cents,credits")
                .eq("status", "completed")
                .execute()
                .data
                or []
            )

        total_cents = sum(int(p["price_amount_cents"]) for p in purchases)
        total_credits = sum(int(p["credits"]) for p in purchases)
        if total_credits > 0:
            return (
                Decimal(total_cents) / Decimal(100) / Decimal(total_credits)
            ).quantize(Decimal("0.000001"))

        # No real purchase history at all yet — use the most conservative real
        # price point: the lowest price-per-credit among active packages.
        packages = (
            self.db.table("credit_packages")
            .select("price_amount_cents,credits")
            .eq("is_active", True)
            .execute()
            .data
            or []
        )
        rates = [
            Decimal(p["price_amount_cents"]) / Decimal(100) / Decimal(p["credits"])
            for p in packages
            if int(p.get("credits") or 0) > 0 and int(p.get("price_amount_cents") or 0) > 0
        ]
        if not rates:
            return Decimal("0")
        return min(rates).quantize(Decimal("0.000001"))

    def _min_gross_margin_bps(self) -> int:
        result = (
            self.db.table("credit_settings")
            .select("min_gross_margin_bps")
            .eq("id", 1)
            .limit(1)
            .execute()
        )
        row = (result.data or [None])[0]
        if row and row.get("min_gross_margin_bps") is not None:
            return int(row["min_gross_margin_bps"])
        return DEFAULT_MIN_GROSS_MARGIN_BPS

    def _persist_snapshot(self, snapshot: MarginSnapshot) -> None:
        self.db.table("tool_margin_snapshots").insert(
            {
                "tool_slug": snapshot.tool_slug,
                "window_days": snapshot.window_days,
                "window_start": snapshot.window_start.isoformat(),
                "window_end": snapshot.window_end.isoformat(),
                "generations_count": snapshot.generations_count,
                "generations_with_cost_count": snapshot.generations_with_cost_count,
                "net_credits": snapshot.net_credits,
                "effective_usd_per_credit": str(snapshot.effective_usd_per_credit),
                "revenue_usd": str(snapshot.revenue_usd),
                "provider_cost_usd": str(snapshot.provider_cost_usd),
                "margin_usd": str(snapshot.margin_usd),
                "suggested_credit_cost": snapshot.suggested_credit_cost,
                "action_taken": snapshot.action_taken,
            }
        ).execute()

    def _disable_tool(self, tool_slug: str) -> None:
        logger.warning("margin_breaker_tripped tool=%s", tool_slug)
        self.db.table("tools").update(
            {
                "is_active": False,
                "disabled_reason": "auto_margin_breaker",
                "disabled_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("slug", tool_slug).eq("is_active", True).execute()
