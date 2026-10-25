from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class CreditBalanceOut(BaseModel):
    user_id: str
    balance: int


class CreditTransactionOut(BaseModel):
    id: str
    user_id: str
    generation_id: Optional[str] = None
    tool_slug: Optional[str] = None
    amount: int
    balance_after: int
    type: str
    reason: Optional[str] = None
    created_at: datetime


class CreditPackageOut(BaseModel):
    slug: str
    name: str
    credits: int
    price_amount_cents: int
    currency: str
    platform: str
    provider_product_id: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    sort_order: int = 100
    # Derived store helpers (not DB columns)
    price_per_credit_cents: Optional[float] = None
    is_profitable: bool = True


class CreditSettingsOut(BaseModel):
    min_topup_credits: int
    max_topup_credits: int
    max_balance_credits: int
    provider_cost_cents_per_credit: int = 1
    min_gross_margin_bps: int = 2000


class CreditPurchaseRequest(BaseModel):
    package_slug: str = Field(min_length=1, max_length=80)
    idempotency_key: Optional[str] = Field(default=None, max_length=120)

    @field_validator("package_slug")
    @classmethod
    def normalize_slug(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("package_slug is required")
        return cleaned

    @field_validator("idempotency_key")
    @classmethod
    def normalize_key(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None


class CreditPurchaseOut(BaseModel):
    id: str
    user_id: str
    package_slug: str
    package_name: str
    credits: int
    price_amount_cents: int
    currency: str
    status: str
    provider: str
    provider_ref: Optional[str] = None
    balance_after: Optional[int] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
