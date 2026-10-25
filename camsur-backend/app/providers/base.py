"""Shared provider interface."""

from __future__ import annotations

from dataclasses import dataclass

from app.config import Settings


@dataclass(frozen=True)
class ProviderResult:
    image_bytes: bytes
    request_id: str | None = None


class BaseProvider:
    """One platform = one provider. Returns generated image bytes + optional request id."""

    name: str = "base"

    def __init__(self, settings: Settings):
        self.settings = settings

    async def edit_image(
        self,
        prompt: str,
        *,
        input_image_url: str | None = None,
        input_image_bytes: bytes | None = None,
        input_image_urls: list[str] | None = None,
        width: int = 1024,
        height: int = 1024,
        guidance: float | None = None,
        steps: int | None = None,
    ) -> ProviderResult:
        raise NotImplementedError
