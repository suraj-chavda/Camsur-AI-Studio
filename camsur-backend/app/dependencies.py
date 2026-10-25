from typing import Annotated

from fastapi import Depends, Header
from supabase import Client

from app.config import Settings, get_settings
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.db.supabase import get_supabase
from app.schemas.user_schema import UserOut
from app.services.admin_analytics_service import AdminAnalyticsService
from app.services.admin_service import AdminService
from app.services.auth_service import AuthService
from app.services.credit_service import CreditService
from app.services.generation_service import GenerationService
from app.services.margin_monitor_service import MarginMonitorService
from app.services.media_cleanup_service import MediaCleanupService
from app.services.storage_service import StorageService
from app.services.tool_service import ToolService

SettingsDep = Annotated[Settings, Depends(get_settings)]
DbDep = Annotated[Client, Depends(get_supabase)]


def get_auth_service(db: DbDep) -> AuthService:
    return AuthService(db)


def get_storage_service(db: DbDep, settings: SettingsDep) -> StorageService:
    return StorageService(db, settings)


def get_tool_service(db: DbDep, settings: SettingsDep) -> ToolService:
    return ToolService(db, settings)


def get_credit_service(db: DbDep, settings: SettingsDep) -> CreditService:
    return CreditService(db, settings)


def get_generation_service(
    db: DbDep,
    settings: SettingsDep,
    storage: Annotated[StorageService, Depends(get_storage_service)],
    tools: Annotated[ToolService, Depends(get_tool_service)],
    credits: Annotated[CreditService, Depends(get_credit_service)],
) -> GenerationService:
    return GenerationService(
        db=db,
        settings=settings,
        storage=storage,
        tools=tools,
        credits=credits,
    )


def get_admin_service(
    db: DbDep,
    settings: SettingsDep,
    credits: Annotated[CreditService, Depends(get_credit_service)],
) -> AdminService:
    return AdminService(db, settings, credits)


def get_admin_analytics_service(db: DbDep, settings: SettingsDep) -> AdminAnalyticsService:
    return AdminAnalyticsService(db, settings)


def get_margin_monitor_service(db: DbDep, settings: SettingsDep) -> MarginMonitorService:
    return MarginMonitorService(db, settings)


def get_media_cleanup_service(
    db: DbDep,
    settings: SettingsDep,
    storage: Annotated[StorageService, Depends(get_storage_service)],
) -> MediaCleanupService:
    return MediaCleanupService(db, settings, storage)


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]
StorageServiceDep = Annotated[StorageService, Depends(get_storage_service)]
ToolServiceDep = Annotated[ToolService, Depends(get_tool_service)]
CreditServiceDep = Annotated[CreditService, Depends(get_credit_service)]
GenerationServiceDep = Annotated[GenerationService, Depends(get_generation_service)]
AdminServiceDep = Annotated[AdminService, Depends(get_admin_service)]
AdminAnalyticsServiceDep = Annotated[AdminAnalyticsService, Depends(get_admin_analytics_service)]
MarginMonitorServiceDep = Annotated[MarginMonitorService, Depends(get_margin_monitor_service)]
MediaCleanupServiceDep = Annotated[MediaCleanupService, Depends(get_media_cleanup_service)]


async def get_current_user(
    auth: AuthServiceDep,
    authorization: Annotated[str | None, Header()] = None,
) -> UserOut:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise UnauthorizedError("Missing Bearer token")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise UnauthorizedError("Missing Bearer token")

    return await auth.get_user_from_token(token)


CurrentUserDep = Annotated[UserOut, Depends(get_current_user)]


async def get_current_admin(current_user: CurrentUserDep) -> UserOut:
    if current_user.role != "admin":
        raise ForbiddenError("Admin access required")
    return current_user


AdminUserDep = Annotated[UserOut, Depends(get_current_admin)]
