"""Per-user / global generation and credit spend guards (pre-charge)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from supabase import Client

from app.config import Settings
from app.core.enums import JobStatus
from app.core.exceptions import RateLimitedError, ServiceUnavailableError


ACTIVE_STATUSES = (
    JobStatus.PENDING.value,
    JobStatus.PROCESSING.value,
)


class GenerationLimitService:
    def __init__(self, db: Client, settings: Settings):
        self.db = db
        self.settings = settings

    def assert_generation_allowed(self, user_id: str, credit_cost: int) -> None:
        if not self.settings.ai_generation_enabled:
            raise ServiceUnavailableError("AI generation is temporarily disabled")
        if self.settings.generation_maintenance_mode:
            raise ServiceUnavailableError("AI generation is temporarily unavailable")

        now = datetime.now(timezone.utc)
        hour_ago = (now - timedelta(hours=1)).isoformat()
        day_ago = (now - timedelta(days=1)).isoformat()

        if self.settings.max_concurrent_generations_per_user > 0:
            active = (
                self.db.table("generations")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .in_("status", list(ACTIVE_STATUSES))
                .is_("deleted_at", "null")
                .execute()
            )
            if (active.count or 0) >= self.settings.max_concurrent_generations_per_user:
                raise RateLimitedError("Too many generations in progress. Try again shortly.")

        if self.settings.max_global_active_generations > 0:
            global_active = (
                self.db.table("generations")
                .select("id", count="exact")
                .in_("status", list(ACTIVE_STATUSES))
                .is_("deleted_at", "null")
                .execute()
            )
            if (global_active.count or 0) >= self.settings.max_global_active_generations:
                raise ServiceUnavailableError("Generation capacity is full. Try again shortly.")

        if self.settings.max_generations_per_user_per_hour > 0:
            hourly = (
                self.db.table("generations")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .gte("created_at", hour_ago)
                .execute()
            )
            if (hourly.count or 0) >= self.settings.max_generations_per_user_per_hour:
                raise RateLimitedError("Hourly generation limit reached")

        if self.settings.max_generations_per_user_per_day > 0:
            daily = (
                self.db.table("generations")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .gte("created_at", day_ago)
                .execute()
            )
            if (daily.count or 0) >= self.settings.max_generations_per_user_per_day:
                raise RateLimitedError("Daily generation limit reached")

        if self.settings.max_global_generations_per_hour > 0:
            global_hourly = (
                self.db.table("generations")
                .select("id", count="exact")
                .gte("created_at", hour_ago)
                .execute()
            )
            if (global_hourly.count or 0) >= self.settings.max_global_generations_per_hour:
                raise ServiceUnavailableError("Global generation limit reached. Try again shortly.")

        if credit_cost > 0 and self.settings.max_credits_spent_per_user_per_hour > 0:
            spent_hour = self._sum_spend(user_id, hour_ago)
            if spent_hour + credit_cost > self.settings.max_credits_spent_per_user_per_hour:
                raise RateLimitedError("Hourly credit spend limit reached")

        if credit_cost > 0 and self.settings.max_credits_spent_per_user_per_day > 0:
            spent_day = self._sum_spend(user_id, day_ago)
            if spent_day + credit_cost > self.settings.max_credits_spent_per_user_per_day:
                raise RateLimitedError("Daily credit spend limit reached")

    def _sum_spend(self, user_id: str, since_iso: str) -> int:
        rows = (
            self.db.table("credit_transactions")
            .select("amount")
            .eq("user_id", user_id)
            .eq("type", "spend")
            .gte("created_at", since_iso)
            .execute()
        )
        total = 0
        for row in rows.data or []:
            amount = int(row.get("amount") or 0)
            if amount < 0:
                total += -amount
        return total
