from fastapi import APIRouter, Query

from app.core.response import ok
from app.dependencies import (
    AdminAnalyticsServiceDep,
    AdminServiceDep,
    AdminUserDep,
    MarginMonitorServiceDep,
    MediaCleanupServiceDep,
)
from app.schemas.admin_schema import (
    AdminGrantCreditsRequest,
    AdminToolToggleRequest,
    AdminToolUpdateRequest,
    AdminUserUpdateRequest,
    CreditPackageCreateRequest,
    CreditPackageUpdateRequest,
    CreditSettingsUpdateRequest,
    paginated,
)

router = APIRouter(prefix="/admin", tags=["admin"])


# ---- analytics ----------------------------------------------------------


@router.get("/analytics/overview")
async def analytics_overview(
    _admin: AdminUserDep,
    analytics: AdminAnalyticsServiceDep,
    days: int = Query(default=7, ge=1, le=90),
):
    return ok(data=analytics.usage_summary(days))


@router.get("/analytics/margin")
async def analytics_margin(
    _admin: AdminUserDep,
    monitor: MarginMonitorServiceDep,
    days: int | None = Query(default=None, ge=1, le=90),
):
    snapshots = monitor.evaluate(days)
    return ok(data=[s.__dict__ for s in snapshots])


@router.get("/analytics/top-users")
async def analytics_top_users(
    _admin: AdminUserDep,
    analytics: AdminAnalyticsServiceDep,
    days: int = Query(default=7, ge=1, le=90),
    limit: int = Query(default=20, ge=1, le=100),
):
    return ok(data=analytics.top_users(days, limit=limit))


@router.get("/margin-snapshots")
async def margin_snapshots(
    _admin: AdminUserDep,
    analytics: AdminAnalyticsServiceDep,
    tool_slug: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    items, total = analytics.margin_snapshots(tool_slug=tool_slug, limit=limit, offset=offset)
    return ok(data=paginated(items, total))


@router.get("/health/ledger")
async def health_ledger(
    _admin: AdminUserDep,
    analytics: AdminAnalyticsServiceDep,
    limit: int = Query(default=500, ge=1, le=2000),
):
    return ok(data=analytics.ledger_health(limit=limit))


# ---- ops actions ----------------------------------------------------------


@router.post("/margin/recompute")
async def margin_recompute(_admin: AdminUserDep, monitor: MarginMonitorServiceDep):
    snapshots = monitor.recompute_and_enforce()
    return ok(
        data=[s.__dict__ for s in snapshots],
        message="Margin recompute complete",
    )


@router.post("/media-cleanup/run")
async def media_cleanup_run(
    _admin: AdminUserDep,
    cleanup: MediaCleanupServiceDep,
    dry_run: bool = Query(default=True),
    limit: int = Query(default=200, ge=1, le=1000),
):
    stats = cleanup.run(limit=limit, dry_run=dry_run)
    return ok(data=stats.__dict__)


@router.post("/tools/{slug}/reenable")
async def reenable_tool(slug: str, _admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.reenable_tool(slug), message=f"{slug} re-enabled")


@router.post("/tools/{slug}/toggle")
async def toggle_tool(
    slug: str,
    body: AdminToolToggleRequest,
    _admin: AdminUserDep,
    service: AdminServiceDep,
):
    return ok(data=service.toggle_tool(slug, body.is_active))


# ---- tools ----------------------------------------------------------------


@router.get("/tools")
async def list_tools(_admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.list_tools())


@router.get("/tools/{slug}")
async def get_tool(slug: str, _admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.get_tool(slug))


@router.patch("/tools/{slug}")
async def update_tool(
    slug: str,
    body: AdminToolUpdateRequest,
    _admin: AdminUserDep,
    service: AdminServiceDep,
):
    return ok(
        data=service.update_tool(
            slug, credit_cost=body.credit_cost, sort_order=body.sort_order
        )
    )


# ---- users ------------------------------------------------------------


@router.get("/users")
async def list_users(
    _admin: AdminUserDep,
    service: AdminServiceDep,
    search: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    items, total = service.list_users(limit=limit, offset=offset, search=search)
    return ok(data=paginated(items, total))


@router.get("/users/{user_id}")
async def get_user(user_id: str, _admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.get_user(user_id))


@router.patch("/users/{user_id}")
async def update_user(
    user_id: str,
    body: AdminUserUpdateRequest,
    _admin: AdminUserDep,
    service: AdminServiceDep,
):
    return ok(
        data=service.update_user(
            user_id, display_name=body.display_name, role=body.role
        )
    )


@router.post("/users/{user_id}/credits/grant")
async def grant_credits(
    user_id: str,
    body: AdminGrantCreditsRequest,
    admin: AdminUserDep,
    service: AdminServiceDep,
):
    tx = await service.grant_credits(
        user_id, amount=body.amount, reason=body.reason, admin_id=admin.id
    )
    return ok(data=tx.model_dump(), message=f"Granted {body.amount} credit(s)")


# ---- generations ------------------------------------------------------


@router.get("/generations")
async def list_generations(
    _admin: AdminUserDep,
    service: AdminServiceDep,
    status: str | None = None,
    tool_slug: str | None = None,
    user_id: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    items, total = service.list_generations(
        limit=limit, offset=offset, status=status, tool_slug=tool_slug, user_id=user_id
    )
    return ok(data=paginated(items, total))


@router.get("/generations/{generation_id}")
async def get_generation(
    generation_id: str, _admin: AdminUserDep, service: AdminServiceDep
):
    return ok(data=service.get_generation(generation_id))


@router.post("/generations/{generation_id}/refund")
async def refund_generation(
    generation_id: str, _admin: AdminUserDep, service: AdminServiceDep
):
    return ok(data=await service.refund_generation(generation_id), message="Refunded")


# ---- credit purchases ---------------------------------------------------


@router.get("/credit-purchases")
async def list_credit_purchases(
    _admin: AdminUserDep,
    service: AdminServiceDep,
    status: str | None = None,
    user_id: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    items, total = service.list_credit_purchases(
        limit=limit, offset=offset, status=status, user_id=user_id
    )
    return ok(data=paginated(items, total))


# ---- credit packages (full CRUD) ---------------------------------------


@router.get("/credit-packages")
async def list_credit_packages(_admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.list_credit_packages())


@router.post("/credit-packages")
async def create_credit_package(
    body: CreditPackageCreateRequest, _admin: AdminUserDep, service: AdminServiceDep
):
    return ok(data=service.create_credit_package(body.model_dump()), message="Created")


@router.patch("/credit-packages/{slug}")
async def update_credit_package(
    slug: str,
    body: CreditPackageUpdateRequest,
    _admin: AdminUserDep,
    service: AdminServiceDep,
):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    return ok(data=service.update_credit_package(slug, payload))


# ---- credit settings (singleton) ---------------------------------------


@router.get("/credit-settings")
async def get_credit_settings(_admin: AdminUserDep, service: AdminServiceDep):
    return ok(data=service.get_credit_settings())


@router.patch("/credit-settings")
async def update_credit_settings(
    body: CreditSettingsUpdateRequest, _admin: AdminUserDep, service: AdminServiceDep
):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    return ok(data=service.update_credit_settings(payload))
