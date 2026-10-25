"""AI image providers (BFL, OpenAI, …). One interface, many platforms."""

from app.config import Settings
from app.core.enums import AIProviderName
from app.core.exceptions import ValidationError
from app.providers.base import BaseProvider
from app.providers.bfl_provider import BflProvider


def get_provider(settings: Settings, *, model_override: str | None = None) -> BaseProvider:
    name = (settings.ai_provider or AIProviderName.BFL.value).lower()

    if name == AIProviderName.BFL.value:
        return BflProvider(settings, model_override=model_override)

    raise ValidationError(f"Unknown AI provider: {settings.ai_provider}")
