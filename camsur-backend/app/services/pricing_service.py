"""Central generation pricing snapshot (Camsur credits ≠ provider USD)."""

from __future__ import annotations

import time
from dataclasses import dataclass
from decimal import ROUND_CEILING, Decimal

from app.config import Settings
from app.core.credits import calculate_credit_cost
from app.schemas.tool_schema import ToolConfig


@dataclass(frozen=True)
class GenerationPricing:
    provider: str
    model: str
    tool_slug: str
    width: int
    height: int
    credit_cost: int
    pricing_version: int


@dataclass(frozen=True)
class ModelRates:
    """$/MP rates for one BFL model — same attribute names
    estimate_provider_cost_usd() reads off `settings`, so either a real
    Settings object or one of these can be passed to it interchangeably.
    """

    bfl_output_first_mp_usd: str
    bfl_output_additional_mp_usd: str
    bfl_input_mp_usd: str


DEFAULT_MODEL_SLUG = "flux-2-pro"
DEFAULT_MODEL_RATES = ModelRates(
    bfl_output_first_mp_usd="0.03",
    bfl_output_additional_mp_usd="0.015",
    bfl_input_mp_usd="0.015",
)

_MODEL_CACHE_TTL_SEC = 60
_cached_model_slug: str | None = None
_cached_model_rates: ModelRates | None = None
_cached_model_at: float = 0.0


def get_active_model(db) -> tuple[str, ModelRates]:
    """The admin-selected active BFL model + its $/MP rates, from
    ai_provider_settings / bfl_model_catalog. Cached briefly like the tool
    catalog — falls back to the Pro-tier defaults on any DB hiccup so a
    misconfigured/missing settings row never blocks generation.
    Synchronous (matches ToolService/GenerationService's other DB reads) —
    call via asyncio.to_thread from async code.
    """
    global _cached_model_slug, _cached_model_rates, _cached_model_at
    now = time.monotonic()
    if _cached_model_slug and (now - _cached_model_at) < _MODEL_CACHE_TTL_SEC:
        return _cached_model_slug, _cached_model_rates

    slug, rates = DEFAULT_MODEL_SLUG, DEFAULT_MODEL_RATES
    try:
        settings_rows = (
            db.table("ai_provider_settings").select("active_model").eq("id", 1).limit(1).execute().data
        )
        if settings_rows and settings_rows[0].get("active_model"):
            slug = settings_rows[0]["active_model"]

        model_rows = db.table("bfl_model_catalog").select("*").eq("slug", slug).limit(1).execute().data
        if model_rows:
            m = model_rows[0]
            rates = ModelRates(
                bfl_output_first_mp_usd=str(m["output_first_mp_usd"]),
                bfl_output_additional_mp_usd=str(m["output_additional_mp_usd"]),
                bfl_input_mp_usd=str(m["input_mp_usd"]),
            )
        else:
            slug = DEFAULT_MODEL_SLUG
    except Exception:
        slug, rates = DEFAULT_MODEL_SLUG, DEFAULT_MODEL_RATES

    _cached_model_slug, _cached_model_rates, _cached_model_at = slug, rates, now
    return slug, rates


def clear_model_cache() -> None:
    global _cached_model_slug, _cached_model_rates, _cached_model_at
    _cached_model_slug = None
    _cached_model_rates = None
    _cached_model_at = 0.0


def cheapest_active_package_usd_per_credit(db) -> Decimal:
    """Real, DB-driven $/credit baseline that doesn't require any purchase
    history yet — the cheapest currently-active credit_packages rate. Used
    to recommend tool pricing right after switching models, before any
    generations on the new model exist to compute a realized rate from.
    """
    packages = db.table("credit_packages").select("price_amount_cents,credits").eq("is_active", True).execute().data or []
    rates = [
        Decimal(p["price_amount_cents"]) / Decimal(100) / Decimal(p["credits"])
        for p in packages
        if int(p.get("credits") or 0) > 0 and int(p.get("price_amount_cents") or 0) > 0
    ]
    return min(rates) if rates else Decimal("0")


def recommend_credit_cost(
    *,
    width: int,
    height: int,
    num_input_images: int,
    rates: ModelRates,
    usd_per_credit: Decimal,
    min_margin_bps: int,
) -> int:
    """Minimum whole-credit price that keeps at least `min_margin_bps` gross
    margin over the estimated provider cost for one generation, given the
    active model's rates and the cheapest real credit-package rate.
    """
    if usd_per_credit <= 0:
        return 0
    cost = estimate_provider_cost_usd(width, height, rates, num_input_images=num_input_images)
    required_usd = cost * (Decimal(10_000 + max(0, min_margin_bps)) / Decimal(10_000))
    return int((required_usd / usd_per_credit).to_integral_value(rounding=ROUND_CEILING))


def resolve_generation_pricing(tool: ToolConfig, settings: Settings) -> GenerationPricing:
    """
    Resolve the charge for a tool from trusted server config/DB — never from the client.

    Preserves existing catalog prices (10 / 15). Does not derive credits from BFL USD.
    """
    credit_cost = calculate_credit_cost(tool_credit_cost=int(tool.credit_cost))
    return GenerationPricing(
        provider=settings.ai_provider,
        model=settings.bfl_model if settings.ai_provider == "bfl" else settings.ai_provider,
        tool_slug=tool.slug,
        width=int(tool.width),
        height=int(tool.height),
        credit_cost=credit_cost,
        pricing_version=settings.pricing_version,
    )


def estimate_provider_cost_usd(
    width: int, height: int, settings: Settings, *, num_input_images: int = 1
) -> Decimal:
    """
    Conservative estimated real-dollar BFL cost for one generation, from megapixels.

    FLUX.2 [pro] bills output megapixels on a tier (first MP flat, each
    additional MP cheaper) plus a flat per-MP charge for every reference
    image sent as input. We don't know each input image's real pixel size
    (not probed in this pipeline), so — conservatively, to avoid
    understating cost — each input image is assumed to cost as much as one
    output megapixel-tier unit at the input rate.

    Used for FinOps/margin monitoring only — never for what the user is charged.
    Rounds up (ROUND_CEILING) to avoid understating cost.
    """
    mp = Decimal(int(width) * int(height)) / Decimal(1_000_000)
    first_mp_rate = Decimal(str(settings.bfl_output_first_mp_usd))
    additional_mp_rate = Decimal(str(settings.bfl_output_additional_mp_usd))
    input_mp_rate = Decimal(str(settings.bfl_input_mp_usd))

    output_cost = first_mp_rate + max(mp - 1, Decimal(0)) * additional_mp_rate
    input_cost = input_mp_rate * mp * Decimal(max(1, int(num_input_images)))

    return (output_cost + input_cost).quantize(Decimal("0.0001"), rounding=ROUND_CEILING)
