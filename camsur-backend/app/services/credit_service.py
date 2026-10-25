import asyncio
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from supabase import Client

from app.config import Settings
from app.core.exceptions import NotFoundError, ValidationError
from app.core.logging import get_logger
from app.schemas.credit_schema import (
    CreditBalanceOut,
    CreditPackageOut,
    CreditPurchaseOut,
    CreditSettingsOut,
    CreditTransactionOut,
)

logger = get_logger(__name__)


class CreditService:
    def __init__(self, db: Client, settings: Settings | None = None):
        self.db = db
        self.settings = settings

    async def get_balance(self, user_id: str) -> CreditBalanceOut:
        return await asyncio.to_thread(self._get_balance, user_id)

    async def list_transactions(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[CreditTransactionOut]:
        rows = await asyncio.to_thread(self._list_transactions, user_id, limit)
        return [CreditTransactionOut.model_validate(row) for row in rows]

    async def list_packages(self) -> list[CreditPackageOut]:
        try:
            settings = await self.get_settings()
        except Exception:
            logger.exception("credit_settings_unavailable_using_defaults")
            settings = CreditSettingsOut(
                min_topup_credits=100,
                max_topup_credits=2000,
                max_balance_credits=10000,
                provider_cost_cents_per_credit=1,
                min_gross_margin_bps=2000,
            )
        try:
            rows = await asyncio.to_thread(self._list_packages)
        except Exception:
            # Propagate so clients retry instead of caching a false empty catalog.
            logger.exception("credit_packages_query_failed")
            raise

        packages: list[CreditPackageOut] = []
        for row in rows:
            try:
                package = self._package_from_row(row, settings)
            except Exception:
                logger.exception(
                    "credit_package_row_skipped slug=%s",
                    row.get("slug"),
                )
                continue
            # Never expose loss-making or out-of-bounds packs to the store.
            if not package.is_profitable:
                continue
            if package.credits < settings.min_topup_credits:
                continue
            if package.credits > settings.max_topup_credits:
                continue
            packages.append(package)
        return packages

    async def get_settings(self) -> CreditSettingsOut:
        row = await asyncio.to_thread(self._get_settings)
        return CreditSettingsOut.model_validate(row)

    async def purchase_package(
        self,
        *,
        user_id: str,
        package_slug: str,
        idempotency_key: str | None = None,
    ) -> CreditPurchaseOut:
        return await asyncio.to_thread(
            self._purchase_package,
            user_id,
            package_slug,
            idempotency_key,
        )

    async def spend_for_generation(
        self,
        *,
        user_id: str,
        amount: int,
        generation_id: str,
        tool_slug: str,
        metadata: dict[str, Any] | None = None,
    ) -> CreditTransactionOut | None:
        if amount <= 0:
            return None

        row = await asyncio.to_thread(
            self._spend_for_generation,
            user_id,
            amount,
            generation_id,
            tool_slug,
            metadata or {},
        )
        return CreditTransactionOut.model_validate(row)

    async def refund_generation(
        self,
        *,
        user_id: str,
        amount: int,
        generation_id: str,
        tool_slug: str,
        reason: str = "generation_failed",
        metadata: dict[str, Any] | None = None,
    ) -> CreditTransactionOut | None:
        if amount <= 0:
            return None

        row = await asyncio.to_thread(
            self._refund_generation,
            user_id,
            amount,
            generation_id,
            tool_slug,
            reason,
            metadata or {},
        )
        return CreditTransactionOut.model_validate(row)

    async def grant_manual(
        self,
        *,
        user_id: str,
        amount: int,
        reason: str = "manual_topup",
        idempotency_key: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> CreditTransactionOut:
        row = await asyncio.to_thread(
            self._grant_manual,
            user_id,
            amount,
            reason,
            idempotency_key,
            metadata or {},
        )
        return CreditTransactionOut.model_validate(row)

    def ensure_account(self, user_id: str) -> None:
        self._ensure_account(user_id)

    def _get_balance(self, user_id: str) -> CreditBalanceOut:
        row = self._ensure_account(user_id)
        return CreditBalanceOut(user_id=row["user_id"], balance=row["balance"])

    def _list_transactions(self, user_id: str, limit: int) -> list[dict]:
        result = (
            self.db.table("credit_transactions")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data or []

    def _list_packages(self) -> list[dict]:
        result = (
            self.db.table("credit_packages")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return result.data or []

    def _get_package(self, slug: str) -> dict | None:
        result = (
            self.db.table("credit_packages")
            .select("*")
            .eq("slug", slug)
            .eq("is_active", True)
            .limit(1)
            .execute()
        )
        return (result.data or [None])[0]

    def _get_settings(self) -> dict:
        try:
            result = (
                self.db.table("credit_settings")
                .select(
                    "min_topup_credits,max_topup_credits,max_balance_credits,"
                    "provider_cost_cents_per_credit,min_gross_margin_bps"
                )
                .eq("id", 1)
                .limit(1)
                .execute()
            )
        except Exception:
            result = (
                self.db.table("credit_settings")
                .select("min_topup_credits,max_topup_credits,max_balance_credits")
                .eq("id", 1)
                .limit(1)
                .execute()
            )
        if not result.data:
            raise ValidationError("Credit settings are not configured")
        row = dict(result.data[0])
        row.setdefault("provider_cost_cents_per_credit", 1)
        row.setdefault("min_gross_margin_bps", 2000)
        return row

    def _package_from_row(
        self,
        row: dict,
        settings: CreditSettingsOut,
    ) -> CreditPackageOut:
        credits = int(row["credits"])
        price = int(row["price_amount_cents"])
        per = (price / credits) if credits > 0 else 0.0
        profitable = self._is_profitable(
            credits=credits,
            price_cents=price,
            settings=settings,
        )
        return CreditPackageOut(
            slug=row["slug"],
            name=row["name"],
            credits=credits,
            price_amount_cents=price,
            currency=row.get("currency") or "USD",
            platform=row.get("platform") or "manual",
            provider_product_id=row.get("provider_product_id"),
            metadata=dict(row.get("metadata") or {}),
            sort_order=int(row.get("sort_order") or 100),
            price_per_credit_cents=round(per, 4),
            is_profitable=profitable,
        )

    @staticmethod
    def _is_profitable(
        *,
        credits: int,
        price_cents: int,
        settings: CreditSettingsOut,
    ) -> bool:
        """Reject packs that would sell credits below cost + required margin."""
        if credits <= 0 or price_cents <= 0:
            return False
        # price * 10000 >= credits * cost * (10000 + margin_bps)
        required = (
            credits
            * settings.provider_cost_cents_per_credit
            * (10_000 + settings.min_gross_margin_bps)
        )
        return price_cents * 10_000 >= required

    def _purchase_package(
        self,
        user_id: str,
        package_slug: str,
        idempotency_key: str | None,
    ) -> CreditPurchaseOut:
        settings = CreditSettingsOut.model_validate(self._get_settings())
        package_row = self._get_package(package_slug)
        if not package_row:
            raise NotFoundError("Credit package not found")

        package = self._package_from_row(package_row, settings)
        self._validate_topup_package(package, settings)

        balance = self._ensure_account(user_id)["balance"]
        if balance + package.credits > settings.max_balance_credits:
            raise ValidationError(
                "This top-up would exceed the maximum credit balance"
            )

        key = idempotency_key or f"purchase:{user_id}:{package.slug}:{uuid4()}"
        existing = self._get_purchase_by_idempotency(key)
        if existing:
            return self._purchase_out(existing)

        if not self._manual_topup_enabled():
            raise ValidationError(
                "Paid top-ups are not enabled yet. Contact support to add credits."
            )

        purchase_id = str(uuid4())
        insert_payload = {
            "id": purchase_id,
            "user_id": user_id,
            "package_slug": package.slug,
            "package_name": package.name,
            "credits": package.credits,
            "price_amount_cents": package.price_amount_cents,
            "currency": package.currency,
            "status": "pending",
            "provider": "manual",
            "idempotency_key": key,
            "metadata": {
                "price_per_credit_cents": package.price_per_credit_cents,
                "min_gross_margin_bps": settings.min_gross_margin_bps,
                "provider_cost_cents_per_credit": (
                    settings.provider_cost_cents_per_credit
                ),
            },
        }

        try:
            created = (
                self.db.table("credit_purchases")
                .insert(insert_payload)
                .execute()
            )
            purchase = created.data[0]
        except Exception as exc:
            # Race on idempotency — return the winner.
            existing = self._get_purchase_by_idempotency(key)
            if existing:
                return self._purchase_out(existing)
            logger.warning("credit_purchase_insert_failed error=%s", exc)
            raise ValidationError("Could not start top-up") from exc

        try:
            tx = self._purchase_credits(
                user_id=user_id,
                amount=package.credits,
                reason=f"topup:{package.slug}",
                idempotency_key=f"purchase_tx:{key}",
                metadata={
                    "purchase_id": purchase_id,
                    "package_slug": package.slug,
                    "price_amount_cents": package.price_amount_cents,
                    "currency": package.currency,
                },
            )
        except Exception as exc:
            message = self._map_topup_error(exc)
            self.db.table("credit_purchases").update(
                {
                    "status": "failed",
                    "failure_reason": message,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            ).eq("id", purchase_id).execute()
            raise ValidationError(message) from exc

        now = datetime.now(timezone.utc).isoformat()
        completed = (
            self.db.table("credit_purchases")
            .update(
                {
                    "status": "completed",
                    "credit_transaction_id": tx["id"],
                    "provider_ref": tx.get("idempotency_key"),
                    "completed_at": now,
                    "updated_at": now,
                }
            )
            .eq("id", purchase_id)
            .execute()
        )
        row = (completed.data or [None])[0] or {
            **purchase,
            "status": "completed",
            "credit_transaction_id": tx["id"],
        }
        out = self._purchase_out(row)
        out.balance_after = int(tx["balance_after"])
        logger.info(
            "credit_topup_completed user_id=%s package=%s credits=%s price_cents=%s",
            user_id,
            package.slug,
            package.credits,
            package.price_amount_cents,
        )
        return out

    def _validate_topup_package(
        self,
        package: CreditPackageOut,
        settings: CreditSettingsOut,
    ) -> None:
        if package.credits < settings.min_topup_credits:
            raise ValidationError("Package is below the minimum top-up size")
        if package.credits > settings.max_topup_credits:
            raise ValidationError("Package exceeds the maximum top-up size")
        if package.price_amount_cents <= 0:
            raise ValidationError("Package price is invalid")
        if not package.is_profitable:
            raise ValidationError(
                "This package is temporarily unavailable"
            )

    def _manual_topup_enabled(self) -> bool:
        if self.settings is None:
            return True
        # Hard-disabled in production regardless of the flag — a stray `true` in a
        # prod .env must never bypass real payment collection.
        if self.settings.is_production:
            return False
        return bool(self.settings.credits_manual_topup_enabled)

    def _get_purchase_by_idempotency(self, key: str) -> dict | None:
        result = (
            self.db.table("credit_purchases")
            .select("*")
            .eq("idempotency_key", key)
            .limit(1)
            .execute()
        )
        return (result.data or [None])[0]

    @staticmethod
    def _purchase_out(row: dict) -> CreditPurchaseOut:
        return CreditPurchaseOut.model_validate(
            {
                "id": row["id"],
                "user_id": row["user_id"],
                "package_slug": row["package_slug"],
                "package_name": row["package_name"],
                "credits": row["credits"],
                "price_amount_cents": row["price_amount_cents"],
                "currency": row.get("currency") or "USD",
                "status": row["status"],
                "provider": row.get("provider") or "manual",
                "provider_ref": row.get("provider_ref"),
                "created_at": row["created_at"],
                "completed_at": row.get("completed_at"),
            }
        )

    def _purchase_credits(
        self,
        *,
        user_id: str,
        amount: int,
        reason: str,
        idempotency_key: str,
        metadata: dict[str, Any],
    ) -> dict:
        try:
            result = self.db.rpc(
                "purchase_user_credits",
                {
                    "p_user_id": user_id,
                    "p_amount": amount,
                    "p_reason": reason,
                    "p_idempotency_key": idempotency_key,
                    "p_metadata": metadata,
                },
            ).execute()
        except Exception as exc:
            # Fallback if migration not applied yet — still book as purchase when possible.
            if "purchase_user_credits" in str(exc) or "Could not find the function" in str(
                exc
            ):
                logger.warning(
                    "purchase_user_credits RPC missing; falling back to grant_user_credits"
                )
                result = self.db.rpc(
                    "grant_user_credits",
                    {
                        "p_user_id": user_id,
                        "p_amount": amount,
                        "p_reason": reason,
                        "p_idempotency_key": idempotency_key,
                        "p_metadata": {
                            **metadata,
                            "ledger_type_intended": "purchase",
                        },
                    },
                ).execute()
            else:
                raise
        return _rpc_row(result.data)

    @staticmethod
    def _map_topup_error(exc: Exception) -> str:
        text = str(exc)
        if "topup_below_minimum" in text:
            return "Top-up is below the minimum allowed credits"
        if "topup_above_maximum" in text:
            return "Top-up exceeds the maximum allowed credits"
        if "credit_balance_limit_exceeded" in text:
            return "This top-up would exceed the maximum credit balance"
        if "insufficient" in text.lower():
            return "Unable to complete top-up"
        return "Unable to complete top-up"

    def _ensure_account(self, user_id: str) -> dict:
        result = (
            self.db.table("credit_accounts")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if result.data:
            return result.data[0]

        try:
            created = (
                self.db.table("credit_accounts")
                .insert({"user_id": user_id, "balance": 0})
                .execute()
            )
            return created.data[0]
        except Exception:
            result = (
                self.db.table("credit_accounts")
                .select("*")
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            return result.data[0]

    def _spend_for_generation(
        self,
        user_id: str,
        amount: int,
        generation_id: str,
        tool_slug: str,
        metadata: dict[str, Any],
    ) -> dict:
        from app.core.exceptions import InsufficientCreditsError

        try:
            result = self.db.rpc(
                "spend_user_credits",
                {
                    "p_user_id": user_id,
                    "p_amount": amount,
                    "p_generation_id": generation_id,
                    "p_tool_slug": tool_slug,
                    "p_idempotency_key": f"generation:{generation_id}:spend",
                    "p_metadata": metadata,
                },
            ).execute()
        except Exception as exc:
            if "insufficient_credits" in str(exc):
                raise InsufficientCreditsError(
                    "Insufficient credits for this generation"
                ) from exc
            logger.warning("credit_spend_failed user_id=%s error=%s", user_id, exc)
            raise
        return _rpc_row(result.data)

    def _refund_generation(
        self,
        user_id: str,
        amount: int,
        generation_id: str,
        tool_slug: str,
        reason: str,
        metadata: dict[str, Any],
    ) -> dict:
        result = self.db.rpc(
            "refund_user_credits",
            {
                "p_user_id": user_id,
                "p_amount": amount,
                "p_generation_id": generation_id,
                "p_tool_slug": tool_slug,
                "p_idempotency_key": f"generation:{generation_id}:refund",
                "p_reason": reason,
                "p_metadata": metadata,
            },
        ).execute()
        return _rpc_row(result.data)

    def _grant_manual(
        self,
        user_id: str,
        amount: int,
        reason: str,
        idempotency_key: str | None,
        metadata: dict[str, Any],
    ) -> dict:
        try:
            result = self.db.rpc(
                "grant_user_credits",
                {
                    "p_user_id": user_id,
                    "p_amount": amount,
                    "p_reason": reason,
                    "p_idempotency_key": idempotency_key,
                    "p_metadata": metadata,
                },
            ).execute()
        except Exception as exc:
            raise ValidationError(self._map_topup_error(exc)) from exc
        return _rpc_row(result.data)


def _rpc_row(data: Any) -> dict:
    if isinstance(data, list):
        if not data:
            raise RuntimeError("Credit RPC returned no rows")
        return data[0]
    if isinstance(data, dict):
        return data
    raise RuntimeError("Credit RPC returned no data")
