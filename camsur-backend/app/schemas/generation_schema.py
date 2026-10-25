from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.enums import ImageSource

# Hard global cap — tool min/max must stay within this.
MAX_INPUT_IMAGES = 5
REF_SETTINGS_KEY = "_reference_image_urls"
# Server-only: original identity photos for multi-person (Together) tools.
ORIGIN_SETTINGS_KEY = "_origin_image_urls"


class GenerationCreate(BaseModel):
    tool_slug: str = Field(..., min_length=2, max_length=64)
    source: ImageSource
    # Primary (or sole) input — kept for backward compatibility.
    input_image_url: Optional[str] = Field(default=None, min_length=1, max_length=2048)
    # Preferred: 1–5 Camsur media paths owned by the caller.
    input_image_urls: Optional[list[str]] = Field(default=None, min_length=1, max_length=MAX_INPUT_IMAGES)
    style_notes: Optional[str] = Field(default=None, max_length=500)
    settings: dict[str, Any] = Field(default_factory=dict)
    idempotency_key: Optional[str] = Field(default=None, min_length=8, max_length=128)

    @model_validator(mode="after")
    def _require_inputs(self) -> "GenerationCreate":
        urls = [u.strip() for u in (self.input_image_urls or []) if u and str(u).strip()]
        if self.input_image_url and self.input_image_url.strip():
            primary = self.input_image_url.strip()
            if not urls:
                urls = [primary]
            elif urls[0] != primary:
                urls = [primary] + [u for u in urls if u != primary]
        if not urls:
            raise ValueError("At least one input image is required")
        if len(urls) > MAX_INPUT_IMAGES:
            raise ValueError(f"At most {MAX_INPUT_IMAGES} input images are allowed")
        # Keep slot order. Do not drop duplicate paths here — Together may use
        # the same photo in multiple slots as identity references. Tool normalize
        # decides whether path-dedupe is appropriate.
        self.input_image_urls = urls[:MAX_INPUT_IMAGES]
        self.input_image_url = urls[0]
        return self


class GenerationOut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    user_id: str
    tool_slug: str
    source: str
    status: str
    input_image_url: str
    output_image_url: Optional[str] = None
    style_notes: Optional[str] = None
    settings: dict[str, Any] = Field(default_factory=dict)
    credit_cost: int = 0
    pricing_version: int = 1
    provider: Optional[str] = None
    model: Optional[str] = None
    provider_request_id: Optional[str] = None
    is_saved: bool = False
    credit_spend_transaction_id: Optional[str] = None
    credit_refund_transaction_id: Optional[str] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
