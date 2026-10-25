from functools import lru_cache

from pydantic import computed_field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _split_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


class Settings(BaseSettings):
    """App settings loaded from env / .env."""

    app_name: str = "Camsur AI Studio"
    app_version: str = "1.0.0"
    debug: bool = False
    environment: str = "production"
    api_prefix: str = "/api/v1"

    cors_origins: str = (
        "http://localhost:3000,http://127.0.0.1:3000,"
        "http://localhost:5173,http://127.0.0.1:5173"
    )

    supabase_url: str = ""
    supabase_key: str = ""
    supabase_media_bucket: str = "camsur-media"
    supabase_assets_bucket: str = "camsur-backend-images"
    supabase_bucket: str = ""
    supabase_db_url: str = ""
    signed_url_expires_sec: int = 3600
    signed_url_bfl_expires_sec: int = 7200

    ai_provider: str = "bfl"
    bfl_api_key: str = ""
    bfl_api_base: str = "https://api.bfl.ai"
    bfl_model: str = "flux-2-pro"
    # Keep dual reference until quality A/B proves single-input is equal.
    bfl_duplicate_input_image: bool = True
    # Lower guidance keeps edits closer to the uploaded identity.
    bfl_guidance: float = 3.0
    bfl_steps: int = 50
    # Multi-person composite: stay closer to source faces/bodies to reduce swaps.
    bfl_together_guidance: float = 3.5
    bfl_together_steps: int = 50
    bfl_allowed_result_hosts: str = "bfl.ai,delivery-eu1.bfl.ai,delivery-us1.bfl.ai,api.bfl.ai"
    max_provider_error_log_length: int = 500
    bfl_http_timeout_sec: float = 120.0
    # Total poll budget = interval * attempts. BFL edits can spike well past 60s
    # under load, so budget 5 minutes (1s * 300) before giving up.
    bfl_poll_interval_sec: float = 1.0
    bfl_poll_max_attempts: int = 300
    bfl_max_download_bytes: int = 15 * 1024 * 1024

    pricing_version: int = 1
    # Real FLUX.2 [pro] megapixel-based billing (docs.bfl.ai/quick_start/pricing),
    # used for per-generation provider-cost estimation and margin monitoring —
    # NOT used for user credit charging. Output: first MP flat, each additional
    # MP cheaper. Input (reference images): flat rate per MP, per image.
    bfl_output_first_mp_usd: str = "0.03"
    bfl_output_additional_mp_usd: str = "0.015"
    bfl_input_mp_usd: str = "0.015"

    # Margin circuit breaker (see MarginMonitorService). Reuses credit_settings.
    # min_gross_margin_bps as the margin threshold — no second margin knob.
    background_jobs_enabled: bool = True
    background_job_interval_sec: int = 21600  # 6h: storage cleanup + margin monitor
    margin_monitor_window_days: int = 7
    margin_monitor_min_samples: int = 3

    # Manual top-ups (dev / ops only). Force-disabled in production regardless of
    # this flag (see CreditService._manual_topup_enabled) — production must use a
    # real payment provider. When true (non-prod), POST /credits/purchases
    # completes immediately for catalog packs.
    credits_manual_topup_enabled: bool = False

    # Kill switches / maintenance (no charge when rejecting)
    ai_generation_enabled: bool = True
    generation_maintenance_mode: bool = False

    # Abuse / spend caps (0 = disabled)
    max_generations_per_user_per_hour: int = 30
    max_generations_per_user_per_day: int = 100
    max_credits_spent_per_user_per_hour: int = 500
    max_credits_spent_per_user_per_day: int = 2000
    max_concurrent_generations_per_user: int = 3
    max_global_active_generations: int = 100
    max_global_generations_per_hour: int = 5000

    # Uploads / images
    max_upload_mb: int = 10
    max_image_width: int = 8192
    max_image_height: int = 8192
    max_image_pixels: int = 25_000_000

    # Storage retention (days). 0 = disabled (never auto-expire).
    # Does NOT charge or refund credits on deletion.
    upload_retention_days: int = 30
    output_retention_days: int = 90
    saved_output_retention_days: int = 0

    # Rate limits (in-memory; Redis later)
    rate_limit_enabled: bool = True
    rate_limit_window_sec: int = 60
    rate_limit_ip_per_minute: int = 120
    rate_limit_auth_per_minute: int = 10
    rate_limit_upload_per_minute: int = 20
    rate_limit_generate_per_minute: int = 10

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_required_secrets(self) -> "Settings":
        # Soft validation: allow import/tests without secrets; production should set them.
        return self

    @computed_field  # type: ignore[prop-decorator]
    @property
    def cors_origin_list(self) -> list[str]:
        return _split_csv(self.cors_origins)

    @property
    def bfl_result_host_allowlist(self) -> set[str]:
        return {h.lower() for h in _split_csv(self.bfl_allowed_result_hosts)}

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"prod", "production"} and not self.debug

    @property
    def media_bucket(self) -> str:
        return (self.supabase_bucket or self.supabase_media_bucket).strip()

    @property
    def assets_bucket(self) -> str:
        return self.supabase_assets_bucket.strip() or self.media_bucket

    @property
    def docs_enabled(self) -> bool:
        if self.environment.lower() in {"prod", "production"}:
            return False
        return self.debug


@lru_cache
def get_settings() -> Settings:
    return Settings()
