from fastapi import APIRouter

from app.routes.admin_route import router as admin_router
from app.routes.auth_route import router as auth_router
from app.routes.credit_route import router as credit_router
from app.routes.generation_route import router as generation_router
from app.routes.health_route import router as health_router
from app.routes.tool_route import router as tool_router
from app.routes.upload_route import router as upload_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(credit_router)
api_router.include_router(tool_router)
api_router.include_router(upload_router)
api_router.include_router(generation_router)
api_router.include_router(admin_router)
