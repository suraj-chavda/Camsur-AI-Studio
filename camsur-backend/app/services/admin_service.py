"""
Admin panel: users/generations/credit-purchases/credit-packages/credit-settings/tools
list, detail, and the ops mutations not already owned by an existing service.

Ledger-affecting actions (grant, refund) always go through CreditService's RPC-backed
methods — never write credit_accounts/credit_transactions directly here.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from supabase import Client

from app.config import Settings
from app.core.enums import JobStatus
from app.core.exceptions import NotFoundError, ValidationError
from app.services.credit_service import CreditService
from app.services.tool_service import clear_tool_cache

VALID_ROLES = {"user", "admin"}


class AdminService:
    def __init__(self, db: Client, settings: Settings, credits: CreditService):
        self.db = db
        self.settings = settings
        self.credits = credits

    # ---- users ----------------------------------------------------------

    def list_users(
        self, *, limit: int = 50, offset: int = 0, search: str | None = None
    ) -> tuple[list[dict], int]:
        query = self.db.table("users").select(
            "id,email,display_name,role,created_at,credit_accounts(balance)",
            count="exact",
        )
        if search:
            query = query.ilike("email", f"%{search}%")
        result = (
            query.order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        rows = [self._flatten_user(row) for row in (result.data or [])]
        return rows, result.count or 0

    def get_user(self, user_id: str) -> dict:
        result = (
            self.db.table("users")
            .select("id,email,display_name,role,created_at,credit_accounts(balance)")
            .eq("id", user_id)
            .limit(1)
            .execute()
        )
        if not result.data:
            raise NotFoundError("User not found")
        user = self._flatten_user(result.data[0])

        transactions = (
            self.db.table("credit_transactions")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(20)
            .execute()
            .data
            or []
        )
        gen_count = (
            self.db.table("generations")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .execute()
            .count
            or 0
        )
        user["recent_transactions"] = transactions
        user["generations_count"] = gen_count
        return user

    def update_user(
        self, user_id: str, *, display_name: str | None = None, role: str | None = None
    ) -> dict:
        fields: dict[str, Any] = {}
        if display_name is not None:
            fields["display_name"] = display_name
        if role is not None:
            if role not in VALID_ROLES:
                raise ValidationError(f"role must be one of {sorted(VALID_ROLES)}")
            fields["role"] = role
        if not fields:
            return self.get_user(user_id)

        fields["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = self.db.table("users").update(fields).eq("id", user_id).execute()
        if not result.data:
            raise NotFoundError("User not found")
        return self.get_user(user_id)

    async def grant_credits(self, user_id: str, *, amount: int, reason: str, admin_id: str):
        return await self.credits.grant_manual(
            user_id=user_id,
            amount=amount,
            reason=reason,
            metadata={"granted_by_admin": admin_id},
        )

    @staticmethod
    def _flatten_user(row: dict) -> dict:
        row = dict(row)
        account = row.pop("credit_accounts", None)
        if isinstance(account, list):
            account = account[0] if account else None
        row["balance"] = (account or {}).get("balance", 0)
        return row

    # ---- generations ------------------------------------------------------

    def list_generations(
        self,
        *,
        limit: int = 50,
        offset: int = 0,
        status: str | None = None,
        tool_slug: str | None = None,
        user_id: str | None = None,
    ) -> tuple[list[dict], int]:
        query = self.db.table("generations").select("*", count="exact")
        if status:
            query = query.eq("status", status)
        if tool_slug:
            query = query.eq("tool_slug", tool_slug)
        if user_id:
            query = query.eq("user_id", user_id)
        result = (
            query.order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data or [], result.count or 0

    def get_generation(self, generation_id: str) -> dict:
        result = (
            self.db.table("generations")
            .select("*")
            .eq("id", generation_id)
            .limit(1)
            .execute()
        )
        if not result.data:
            raise NotFoundError("Generation not found")
        return result.data[0]

    async def refund_generation(self, generation_id: str) -> dict:
        row = self.get_generation(generation_id)
        if row["status"] != JobStatus.FAILED.value:
            raise ValidationError(
                "Only generations in 'failed' status can be manually refunded"
            )
        if row.get("credit_refund_transaction_id"):
            raise ValidationError("This generation was already refunded")
        credit_cost = int(row.get("credit_cost") or 0)
        if credit_cost <= 0 or not row.get("credit_spend_transaction_id"):
            raise ValidationError("This generation has nothing to refund")

        tx = await self.credits.refund_generation(
            user_id=row["user_id"],
            amount=credit_cost,
            generation_id=generation_id,
            tool_slug=row["tool_slug"],
            reason="admin_manual_refund",
        )
        self.db.table("generations").update(
            {
                "status": JobStatus.REFUNDED.value,
                "credit_refund_transaction_id": tx.id if tx else None,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", generation_id).execute()
        return self.get_generation(generation_id)

    # ---- credit purchases ---------------------------------------------

    def list_credit_purchases(
        self,
        *,
        limit: int = 50,
        offset: int = 0,
        status: str | None = None,
        user_id: str | None = None,
    ) -> tuple[list[dict], int]:
        query = self.db.table("credit_purchases").select("*", count="exact")
        if status:
            query = query.eq("status", status)
        if user_id:
            query = query.eq("user_id", user_id)
        result = (
            query.order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return result.data or [], result.count or 0

    # ---- credit packages (full CRUD — not YAML-sourced) ----------------

    def list_credit_packages(self) -> list[dict]:
        return (
            self.db.table("credit_packages")
            .select("*")
            .order("sort_order")
            .execute()
            .data
            or []
        )

    def create_credit_package(self, payload: dict) -> dict:
        result = self.db.table("credit_packages").insert(payload).execute()
        if not result.data:
            raise ValidationError("Could not create credit package")
        return result.data[0]

    def update_credit_package(self, slug: str, payload: dict) -> dict:
        fields = {k: v for k, v in payload.items() if v is not None}
        fields["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = (
            self.db.table("credit_packages").update(fields).eq("slug", slug).execute()
        )
        if not result.data:
            raise NotFoundError("Credit package not found")
        return result.data[0]

    # ---- credit settings (singleton) -----------------------------------

    def get_credit_settings(self) -> dict:
        result = (
            self.db.table("credit_settings").select("*").eq("id", 1).limit(1).execute()
        )
        if not result.data:
            raise NotFoundError("Credit settings not configured")
        return result.data[0]

    def update_credit_settings(self, payload: dict) -> dict:
        fields = {k: v for k, v in payload.items() if v is not None}
        if not fields:
            return self.get_credit_settings()
        fields["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = (
            self.db.table("credit_settings").update(fields).eq("id", 1).execute()
        )
        if not result.data:
            raise NotFoundError("Credit settings not configured")
        return result.data[0]

    # ---- tools (operational fields only — content stays YAML-managed) --

    def list_tools(self) -> list[dict]:
        return (
            self.db.table("tools")
            .select("*")
            .order("category")
            .order("sort_order")
            .execute()
            .data
            or []
        )

    def get_tool(self, slug: str) -> dict:
        result = self.db.table("tools").select("*").eq("slug", slug).limit(1).execute()
        if not result.data:
            raise NotFoundError("Tool not found")
        return result.data[0]

    def update_tool(
        self, slug: str, *, credit_cost: int | None = None, sort_order: int | None = None
    ) -> dict:
        fields: dict[str, Any] = {}
        if credit_cost is not None:
            if credit_cost < 0:
                raise ValidationError("credit_cost must be >= 0")
            fields["credit_cost"] = credit_cost
        if sort_order is not None:
            fields["sort_order"] = sort_order
        if not fields:
            return self.get_tool(slug)

        fields["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = self.db.table("tools").update(fields).eq("slug", slug).execute()
        if not result.data:
            raise NotFoundError("Tool not found")
        clear_tool_cache()
        return result.data[0]

    def toggle_tool(self, slug: str, is_active: bool) -> dict:
        fields: dict[str, Any] = {
            "is_active": is_active,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        # A human explicitly choosing to disable is distinct from the automatic
        # margin breaker — keep the audit trail meaningful either way.
        fields["disabled_reason"] = None if is_active else "manual"
        fields["disabled_at"] = None if is_active else datetime.now(timezone.utc).isoformat()
        result = self.db.table("tools").update(fields).eq("slug", slug).execute()
        if not result.data:
            raise NotFoundError("Tool not found")
        clear_tool_cache()
        return result.data[0]

    def reenable_tool(self, slug: str) -> dict:
        result = (
            self.db.table("tools")
            .update(
                {
                    "is_active": True,
                    "disabled_reason": None,
                    "disabled_at": None,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            )
            .eq("slug", slug)
            .execute()
        )
        if not result.data:
            raise NotFoundError("Tool not found")
        clear_tool_cache()
        return result.data[0]
