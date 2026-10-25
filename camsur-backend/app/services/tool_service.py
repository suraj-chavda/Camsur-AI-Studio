import asyncio
import time
from typing import Any

from supabase import Client

from app.config import Settings
from app.core.exceptions import NotFoundError
from app.providers import get_provider
from app.schemas.tool_schema import (
    BannerOut,
    OnboardingSlideOut,
    ToolCatalogCategoryOut,
    ToolCategoryOut,
    ToolConfig,
    ToolOut,
)
from app.services.pricing_service import get_active_model
from app.utils.prompt_util import render_prompt

# Short in-memory cache so every generation does not hit DB for the same tool
_CACHE_TTL_SEC = 60
_cache_tools: list[ToolConfig] | None = None
_cache_categories: list[ToolCategoryOut] | None = None
_cache_banners: list[BannerOut] | None = None
_cache_onboarding: list[OnboardingSlideOut] | None = None
_cache_tools_at: float = 0.0
_cache_categories_at: float = 0.0
_cache_banners_at: float = 0.0
_cache_onboarding_at: float = 0.0


class ToolService:
    def __init__(self, db: Client, settings: Settings):
        self.db = db
        self.settings = settings

    async def list_active(self, search: str | None = None) -> list[ToolOut]:
        tools = await self._load_active()
        if search:
            tools = [t for t in tools if _matches_tool(t, search)]
        return [_to_tool_out(t) for t in tools]

    async def list_trending(self, search: str | None = None) -> list[ToolOut]:
        tools = [tool for tool in await self._load_active() if tool.is_trending]
        tools.sort(key=lambda tool: (tool.trending_sort_order, tool.sort_order, tool.name))
        if search:
            tools = [tool for tool in tools if _matches_tool(tool, search)]
        return [_to_tool_out(t) for t in tools]

    async def list_banners(self) -> list[BannerOut]:
        return await self._load_banners()

    async def list_onboarding(self) -> list[OnboardingSlideOut]:
        return await self._load_onboarding()

    async def list_catalog(self, search: str | None = None) -> list[ToolCatalogCategoryOut]:
        categories = await self._load_categories()
        tools = await self._load_active()
        catalog: list[ToolCatalogCategoryOut] = []

        for category in categories:
            category_tools = [tool for tool in tools if tool.category == category.slug]
            if search:
                category_matches = _matches_category(category, search)
                if not category_matches:
                    category_tools = [tool for tool in category_tools if _matches_tool(tool, search)]

            if not category_tools:
                continue

            catalog.append(
                ToolCatalogCategoryOut(
                    slug=category.slug,
                    name=category.name,
                    description=category.description,
                    icon=category.icon,
                    image_url=category.image_url,
                    sort_order=category.sort_order,
                    tools=[_to_tool_out(tool) for tool in category_tools],
                )
            )

        return catalog

    async def get_by_slug(self, slug: str) -> ToolConfig:
        tools = await self._load_active()
        for tool in tools:
            if tool.slug == slug:
                return tool
        raise NotFoundError(f"Unknown or inactive tool: {slug}")

    async def run(
        self,
        slug: str,
        *,
        input_image_url: str,
        input_image_urls: list[str] | None = None,
        style_notes: str | None = None,
        settings: dict[str, Any] | None = None,
    ) -> tuple[bytes, str | None]:
        tool = await self.get_by_slug(slug)
        prompt_settings = _build_prompt_settings(tool, settings or {})
        notes = _clean_user_text(style_notes)
        urls = [u for u in (input_image_urls or [input_image_url]) if u]
        if not urls:
            urls = [input_image_url]

        render_kwargs: dict[str, Any] = {
            "style_notes": notes,
            "settings": prompt_settings,
        }
        if slug == "together":
            render_kwargs["image_roles"] = _together_image_roles(len(urls))
            render_kwargs["image_count"] = len(urls)
        prompt = render_prompt(tool.prompt_template, **render_kwargs)

        if tool.style_reference_urls:
            prompt, urls = _apply_style_references(prompt, urls, tool.style_reference_urls)

        active_model, _rates = await asyncio.to_thread(get_active_model, self.db)
        provider = get_provider(self.settings, model_override=active_model)
        result = await provider.edit_image(
            prompt=prompt,
            input_image_url=urls[0],
            input_image_urls=urls,
            width=tool.width,
            height=tool.height,
            guidance=tool.guidance,
            steps=tool.steps,
            seed=tool.seed,
            safety_tolerance=tool.safety_tolerance,
            prompt_upsampling=tool.prompt_upsampling,
            output_format=tool.output_format,
        )
        return result.image_bytes, result.request_id

    async def _load_active(self) -> list[ToolConfig]:
        global _cache_tools, _cache_tools_at
        now = time.monotonic()
        if _cache_tools is not None and (now - _cache_tools_at) < _CACHE_TTL_SEC:
            return _cache_tools

        rows = await asyncio.to_thread(self._fetch_active)
        tools: list[ToolConfig] = []
        for row in rows:
            try:
                tools.append(ToolConfig.model_validate(row))
            except Exception:
                continue
        _cache_tools = tools
        _cache_tools_at = now
        return tools

    async def _load_categories(self) -> list[ToolCategoryOut]:
        global _cache_categories, _cache_categories_at
        now = time.monotonic()
        if _cache_categories is not None and (now - _cache_categories_at) < _CACHE_TTL_SEC:
            return _cache_categories

        rows = await asyncio.to_thread(self._fetch_categories)
        categories = [ToolCategoryOut.model_validate(row) for row in rows]
        _cache_categories = categories
        _cache_categories_at = now
        return categories

    async def _load_banners(self) -> list[BannerOut]:
        global _cache_banners, _cache_banners_at
        now = time.monotonic()
        if _cache_banners is not None and (now - _cache_banners_at) < _CACHE_TTL_SEC:
            return _cache_banners

        rows = await asyncio.to_thread(self._fetch_banners)
        banners: list[BannerOut] = []
        for row in rows:
            try:
                banners.append(BannerOut.model_validate(row))
            except Exception:
                continue
        _cache_banners = banners
        _cache_banners_at = now
        return banners

    async def _load_onboarding(self) -> list[OnboardingSlideOut]:
        global _cache_onboarding, _cache_onboarding_at
        now = time.monotonic()
        if _cache_onboarding is not None and (now - _cache_onboarding_at) < _CACHE_TTL_SEC:
            return _cache_onboarding

        rows = await asyncio.to_thread(self._fetch_onboarding)
        slides = [OnboardingSlideOut.model_validate(row) for row in rows]
        _cache_onboarding = slides
        _cache_onboarding_at = now
        return slides

    def _fetch_active(self) -> list[dict]:
        result = (
            self.db.table("tools")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return result.data or []

    def _fetch_categories(self) -> list[dict]:
        result = (
            self.db.table("tool_categories")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return result.data or []

    def _fetch_banners(self) -> list[dict]:
        result = (
            self.db.table("app_banners")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return result.data or []

    def _fetch_onboarding(self) -> list[dict]:
        result = (
            self.db.table("app_onboarding")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return result.data or []


def clear_tool_cache() -> None:
    global _cache_tools, _cache_categories, _cache_banners, _cache_onboarding
    global _cache_tools_at, _cache_categories_at, _cache_banners_at, _cache_onboarding_at

    _cache_tools = None
    _cache_categories = None
    _cache_banners = None
    _cache_onboarding = None
    _cache_tools_at = 0.0
    _cache_categories_at = 0.0
    _cache_banners_at = 0.0
    _cache_onboarding_at = 0.0


def _to_tool_out(tool: ToolConfig) -> ToolOut:
    return ToolOut(
        slug=tool.slug,
        name=tool.name,
        description=tool.description,
        category=tool.category,
        width=tool.width,
        height=tool.height,
        credit_cost=tool.credit_cost,
        min_input_images=tool.min_input_images,
        max_input_images=tool.max_input_images,
        image_url=tool.image_url,
        settings=_public_settings(tool.settings),
        sort_order=tool.sort_order,
        is_trending=tool.is_trending,
        trending_sort_order=tool.trending_sort_order,
    )


def _matches_category(category: ToolCategoryOut, search: str) -> bool:
    haystack = " ".join(
        [
            category.slug,
            category.name,
            category.description,
        ]
    ).lower()
    return search.lower().strip() in haystack


def _public_settings(settings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    public_settings: list[dict[str, Any]] = []
    for setting in settings:
        public_setting = dict(setting)
        public_setting.pop("prompt", None)

        options = []
        for option in setting.get("options") or []:
            public_option = dict(option)
            public_option.pop("prompt", None)
            options.append(public_option)

        if options:
            public_setting["options"] = options

        public_settings.append(public_setting)
    return public_settings


def _matches_tool(tool: ToolConfig, search: str) -> bool:
    haystack_parts: list[str] = [
        tool.slug,
        tool.name,
        tool.description,
        tool.category,
    ]

    for setting in tool.settings:
        haystack_parts.extend(
            str(value)
            for value in [
                setting.get("key"),
                setting.get("label"),
                setting.get("type"),
            ]
            if value
        )
        for option in setting.get("options") or []:
            haystack_parts.extend(
                str(value)
                for value in [
                    option.get("value"),
                    option.get("label"),
                ]
                if value
            )

    haystack = " ".join(haystack_parts).lower()
    return search.lower().strip() in haystack


def _build_prompt_settings(
    tool: ToolConfig,
    selected: dict[str, Any],
) -> dict[str, Any]:
    """Convert user-selected values into prompt-ready setting text."""
    output: dict[str, Any] = {}

    for setting in tool.settings:
        key = setting.get("key")
        if not key:
            continue

        value = selected.get(key, setting.get("default"))
        output[key] = value

        option = _find_option(setting, value)
        if option:
            output[f"{key}_label"] = option.get("label", value)
            output[f"{key}_prompt"] = option.get("prompt", option.get("label", value))
        elif value is not None:
            output[f"{key}_label"] = value
            output[f"{key}_prompt"] = value

    return output


def _find_option(setting: dict[str, Any], value: Any) -> dict[str, Any] | None:
    for option in setting.get("options") or []:
        if option.get("value") == value:
            return option
    return None


def _together_image_roles(image_count: int) -> str:
    """BFL-recommended explicit indexing: 'the person from image N'."""
    n = max(1, min(5, int(image_count or 1)))
    if n == 1:
        return "place the person from image 1 only"
    parts = [f"the person from image {i}" for i in range(1, n + 1)]
    if n == 2:
        joined = f"{parts[0]} and {parts[1]}"
    else:
        joined = ", ".join(parts[:-1]) + f", and {parts[-1]}"
    return (
        f"place {joined} together in one group photo "
        f"(exactly {n} distinct people when using one-photo-per-person mode)"
    )


_MAX_STYLE_REFS = 2  # more than this dilutes "style" into competing subjects — see below


def _apply_style_references(
    prompt: str, urls: list[str], style_reference_urls: list[str]
) -> tuple[str, list[str]]:
    """Adds up to _MAX_STYLE_REFS of the tool's admin-configured style photos
    after the real input photo(s) and PREPENDS a strong instruction pinning
    image 1 as the only real subject.

    Deliberately capped well below BflProvider's 5-image limit: sending
    several distinct style photos alongside one real photo gives the model
    too many candidate "subjects" to choose from, and it can end up
    reproducing a reference's content instead of restyling the real photo —
    the more references, the worse this got in testing. Two is enough to
    convey a style; more competes rather than reinforces.

    The instruction is PREPENDED, not appended — a clarification tacked on
    at the end competed poorly against the tool's own opening instruction
    ("transform the photo...") for which image "the photo" meant once
    several images were in play.
    """
    refs = [u for u in style_reference_urls if u][:_MAX_STYLE_REFS]
    if not refs:
        return prompt, urls

    start = len(urls) + 1
    end = start + len(refs) - 1
    image_word = f"image {start}" if start == end else f"images {start}-{end}"
    note = (
        f"There are multiple images attached. Image 1 is the ONLY real photo — it is the "
        f"one being edited, and the final output must show the exact same person/subject "
        f"from image 1, not a different person or scene.\n"
        f"The other attached {image_word} — {'is' if start == end else 'are'} a style "
        f"reference ONLY (art technique, brushwork, color palette, rendering style). Do not "
        f"output, copy, reproduce, or blend in any face, person, character, object, or "
        f"background from {image_word}. Use {'it' if start == end else 'them'} purely as "
        f"inspiration for HOW to render image 1, never WHAT to render."
    )
    return f"{note}\n\n{prompt}", urls + refs


def _clean_user_text(raw: str | None) -> str | None:
    """Normalize user notes/feedback — whitespace only, no injected text."""
    if not raw:
        return None
    text = " ".join(str(raw).split()).strip()
    if not text:
        return None
    return text[:500]
