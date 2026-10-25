from fastapi import APIRouter

from app.core.response import ok

router = APIRouter(tags=["health"])


@router.get("/health")
async def health():
    return ok(data={"status": "healthy"}, message="Camsur AI Studio is running")
