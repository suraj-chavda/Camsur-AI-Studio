from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class ToolOut(BaseModel):
    slug: str
    name: str
    description: str
    category: str
    width: int
    height: int
    credit_cost: int = 1
    min_input_images: int = 1
    max_input_images: int = 1
    image_url: Optional[str] = None
    settings: list[dict[str, Any]] = Field(default_factory=list)
    sort_order: int = 100
    is_trending: bool = False
    trending_sort_order: int = 100


class ToolCategoryOut(BaseModel):
    slug: str
    name: str
    description: str = ""
    icon: Optional[str] = None
    image_url: Optional[str] = None
    sort_order: int = 100


class ToolCatalogCategoryOut(ToolCategoryOut):
    tools: list[ToolOut] = Field(default_factory=list)


class BannerOut(BaseModel):
    slug: str
    title: str
    subtitle: str = ""
    image_url: Optional[str] = None
    link_type: str = "none"
    link_value: Optional[str] = None
    sort_order: int = 100


class OnboardingSlideOut(BaseModel):
    slug: str
    title: str
    subtitle: str = ""
    image_url: Optional[str] = None
    icon: Optional[str] = None
    sort_order: int = 100


class ToolConfig(BaseModel):
    """Full tool row used by the runner (includes prompt)."""

    slug: str
    name: str
    description: str
    category: str
    prompt_template: str
    settings: list[dict[str, Any]] = Field(default_factory=list)
    credit_cost: int = 1
    min_input_images: int = 1
    max_input_images: int = 1
    image_url: Optional[str] = None
    width: int
    height: int
    # Per-tool BFL generation knobs (mirrors the BFL playground fields) —
    # admin-editable per tool, same pattern as width/height/credit_cost.
    guidance: float = 10.0
    steps: int = 50
    seed: Optional[int] = None
    safety_tolerance: int = 0
    prompt_upsampling: bool = True
    output_format: str = "jpeg"
    # Optional admin-uploaded style/reference images (e.g. a sample art
    # style) — steer visual style only, never identity/background. See
    # ToolService.run()'s style-reference handling.
    style_reference_urls: list[str] = Field(default_factory=list)
    is_active: bool = True
    sort_order: int = 100
    is_trending: bool = False
    trending_sort_order: int = 100
    updated_at: Optional[datetime] = None
