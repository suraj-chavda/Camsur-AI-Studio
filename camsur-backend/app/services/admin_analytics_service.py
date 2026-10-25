"""
Read-only analytics aggregations for the admin panel.

Single source of truth for numbers also surfaced by the FinOps CLI scripts
(scripts/generation_cost_report.py, scripts/abuse_report.py,
scripts/reconcile_credit_balances.py) — those scripts call these same methods
so the CLI and the admin API never disagree.
"""

from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from supabase import Client

from app.config import Settings


class AdminAnalyticsService:
    def __init__(self, db: Client, settings: Settings):
        self.db = db
        self.settings = settings

    def usage_summary(self, days: int) -> dict:
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

        gens = (
            self.db.table("generations")
            .select("id,tool_slug,status,credit_cost,width,height,provider_cost_usd")
            .gte("created_at", since)
            .execute()
            .data
            or []
        )
        txs = (
            self.db.table("credit_transactions")
            .select("amount,type,tool_slug")
            .gte("created_at", since)
            .execute()
            .data
            or []
        )

        by_status = Counter(g["status"] for g in gens)
        by_tool = Counter(g["tool_slug"] for g in gens)
        spend = sum(-int(t["amount"]) for t in txs if t["type"] == "spend" and int(t["amount"]) < 0)
        refund = sum(int(t["amount"]) for t in txs if t["type"] == "refund" and int(t["amount"]) > 0)

        real_provider_cost = sum(
            Decimal(str(g["provider_cost_usd"])) for g in gens if g.get("provider_cost_usd") is not None
        )
        gens_with_cost = sum(1 for g in gens if g.get("provider_cost_usd") is not None)

        return {
            "period_days": days,
            "generations_total": len(gens),
            "by_status": dict(by_status),
            "by_tool": dict(by_tool.most_common()),
            "credits_spent": spend,
            "credits_refunded": refund,
            "net_credits": spend - refund,
            "real_provider_cost_usd": str(real_provider_cost),
            "generations_with_cost_recorded": gens_with_cost,
        }

    def top_users(self, days: int, limit: int = 20) -> list[dict]:
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
        gens = (
            self.db.table("generations")
            .select("user_id,status,credit_cost")
            .gte("created_at", since)
            .execute()
            .data
            or []
        )

        by_user = Counter(g["user_id"] for g in gens)
        spend_by_user: dict[str, int] = defaultdict(int)
        fail_by_user: dict[str, int] = defaultdict(int)
        for g in gens:
            uid = g["user_id"]
            if g["status"] == "completed":
                spend_by_user[uid] += int(g.get("credit_cost") or 0)
            if g["status"] in {"failed", "refunded"}:
                fail_by_user[uid] += 1

        rows = []
        for uid, count in by_user.most_common(limit):
            fails = fail_by_user.get(uid, 0)
            rows.append(
                {
                    "user_id": uid,
                    "generations": count,
                    "credits_spent": spend_by_user.get(uid, 0),
                    "fails": fails,
                    "fail_rate_pct": round((fails / count * 100) if count else 0, 1),
                }
            )
        return rows

    def ledger_health(self, limit: int = 500) -> dict:
        accounts = (
            self.db.table("credit_accounts")
            .select("user_id,balance")
            .limit(limit)
            .execute()
            .data
            or []
        )
        mismatches = []
        for account in accounts:
            user_id = account["user_id"]
            stored = int(account["balance"])
            txs = (
                self.db.table("credit_transactions")
                .select("amount")
                .eq("user_id", user_id)
                .execute()
                .data
                or []
            )
            ledger_sum = sum(int(t["amount"]) for t in txs)
            if ledger_sum != stored:
                mismatches.append(
                    {"user_id": user_id, "balance": stored, "ledger_sum": ledger_sum}
                )

        return {"checked": len(accounts), "mismatches": mismatches}

    def margin_snapshots(
        self,
        *,
        tool_slug: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[dict], int]:
        query = self.db.table("tool_margin_snapshots").select("*", count="exact")
        if tool_slug:
            query = query.eq("tool_slug", tool_slug)
        result = (
            query.order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data or [], result.count or 0
