"""
Admin panel request schemas.

Note: admin list/detail responses are returned as plain dicts straight from
AdminService/AdminAnalyticsService (not validated into Pydantic Out models) —
a deliberate simplification for this internal-only surface, so new internal
columns (provider_cost_usd, disabled_reason, purge timestamps, etc.) are
visible to admins without needing a parallel schema kept in sync with every
table. Request bodies below are still validated normally.
"""

from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


def paginated(items: list, total: int) -> dict:
    return {"items": items, "total": total}


class AdminUserUpdateRequest(BaseModel):
    display_name: Optional[str] = Field(default=None, max_length=120)
    role: Optional[str] = Field(default=None)

    @field_validator("role")
    @classmethod
    def normalize_role(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip().lower()
        if cleaned not in {"user", "admin"}:
            raise ValueError("role must be 'user' or 'admin'")
        return cleaned


class AdminGrantCreditsRequest(BaseModel):
    amount: int = Field(gt=0, le=100_000)
    reason: str = Field(default="admin_grant", max_length=120)


class AdminToolUpdateRequest(BaseModel):
    credit_cost: Optional[int] = Field(default=None, ge=0)
    sort_order: Optional[int] = Field(default=None, ge=0)


class AdminToolToggleRequest(BaseModel):
    is_active: bool


class CreditPackageCreateRequest(BaseModel):
    slug: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=120)
    credits: int = Field(gt=0)
    price_amount_cents: int = Field(gt=0)
    currency: str = Field(default="USD", max_length=8)
    platform: str = Field(default="manual", max_length=40)
    provider_product_id: Optional[str] = Field(default=None, max_length=200)
    metadata: dict[str, Any] = Field(default_factory=dict)
    is_active: bool = False
    sort_order: int = 100

    @field_validator("slug")
    @classmethod
    def normalize_slug(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("slug is required")
        return cleaned


class CreditPackageUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, max_length=120)
    credits: Optional[int] = Field(default=None, gt=0)
    price_amount_cents: Optional[int] = Field(default=None, gt=0)
    currency: Optional[str] = Field(default=None, max_length=8)
    platform: Optional[str] = Field(default=None, max_length=40)
    provider_product_id: Optional[str] = Field(default=None, max_length=200)
    metadata: Optional[dict[str, Any]] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = Field(default=None, ge=0)


class CreditSettingsUpdateRequest(BaseModel):
    min_topup_credits: Optional[int] = Field(default=None, gt=0)
    max_topup_credits: Optional[int] = Field(default=None, gt=0)
    max_balance_credits: Optional[int] = Field(default=None, gt=0)
    provider_cost_cents_per_credit: Optional[int] = Field(default=None, ge=0)
    min_gross_margin_bps: Optional[int] = Field(default=None, ge=0)
