from fastapi import APIRouter

from app.core.response import ok
from app.dependencies import AuthServiceDep, CurrentUserDep
from app.schemas.user_schema import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    SocialLoginRequest,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register")
async def register(payload: RegisterRequest, auth: AuthServiceDep):
    result = await auth.register(payload)
    return ok(data=result.model_dump(), message="Registered")


@router.post("/login")
async def login(payload: LoginRequest, auth: AuthServiceDep):
    result = await auth.login(payload)
    return ok(data=result.model_dump(), message="Logged in")


@router.post("/social")
async def social_login(payload: SocialLoginRequest, auth: AuthServiceDep):
    result = await auth.social_login(payload)
    return ok(data=result.model_dump(), message="Logged in")


@router.post("/refresh")
async def refresh(payload: RefreshRequest, auth: AuthServiceDep):
    result = await auth.refresh(payload.refresh_token)
    return ok(data=result.model_dump(), message="Session refreshed")


@router.get("/me")
async def me(current_user: CurrentUserDep):
    return ok(data=current_user.model_dump())
