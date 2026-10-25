from fastapi import APIRouter, Query

from app.core.response import ok
from app.dependencies import ToolServiceDep

router = APIRouter(prefix="/tools", tags=["tools"])


@router.get("")
async def list_tools(
    service: ToolServiceDep,
    search: str | None = Query(default=None, min_length=1, max_length=80),
):
    """List active AI tools (for mobile app catalog)."""
    tools = await service.list_active(search=search)
    return ok(data=[t.model_dump() for t in tools])


@router.get("/trending")
async def list_trending_tools(
    service: ToolServiceDep,
    search: str | None = Query(default=None, min_length=1, max_length=80),
):
    """List active AI tools selected for the mobile trending section."""
    tools = await service.list_trending(search=search)
    return ok(data=[t.model_dump() for t in tools])


@router.get("/catalog")
async def list_tool_catalog(
    service: ToolServiceDep,
    search: str | None = Query(default=None, min_length=1, max_length=80),
):
    """List active AI tools grouped by category for mobile."""
    categories = await service.list_catalog(search=search)
    return ok(data=[category.model_dump() for category in categories])


@router.get("/banners")
async def list_banners(service: ToolServiceDep):
    """List active home banners for mobile."""
    banners = await service.list_banners()
    return ok(data=[banner.model_dump() for banner in banners])


@router.get("/onboarding")
async def list_onboarding(service: ToolServiceDep):
    """List active onboarding slides for mobile."""
    slides = await service.list_onboarding()
    return ok(data=[slide.model_dump() for slide in slides])
