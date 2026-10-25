from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import get_settings
from app.core.background_jobs import start_background_jobs, stop_background_jobs
from app.core.exceptions import AppError
from app.core.logging import get_logger, setup_logging
from app.core.response import fail
from app.middleware.rate_limit import RateLimitMiddleware
from app.routes import api_router

logger = get_logger(__name__)


@asynccontextmanager
async def _lifespan(app: FastAPI):
    start_background_jobs(app)
    try:
        yield
    finally:
        await stop_background_jobs(app)


def create_app() -> FastAPI:
    setup_logging()
    settings = get_settings()

    docs_url = "/docs" if settings.docs_enabled else None
    redoc_url = "/redoc" if settings.docs_enabled else None
    openapi_url = "/openapi.json" if settings.docs_enabled else None

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=openapi_url,
        lifespan=_lifespan,
    )

    origins = settings.cors_origin_list
    # Never pair allow_credentials with wildcard origins.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept", "X-Requested-With"],
    )
    app.add_middleware(RateLimitMiddleware, settings=settings)

    @app.exception_handler(AppError)
    async def app_error_handler(_request: Request, exc: AppError):
        if exc.status_code >= 500:
            logger.warning("app_error status=%s message=%s", exc.status_code, exc.message)
        return JSONResponse(
            status_code=exc.status_code,
            content=fail(message=exc.message, data=exc.data),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(_request: Request, exc: RequestValidationError):
        errors = []
        for err in exc.errors():
            loc = [str(part) for part in err.get("loc", ()) if part != "body"]
            field = ".".join(loc) if loc else "request"
            errors.append({"field": field, "message": err.get("msg", "Invalid value")})
        message = errors[0]["message"] if len(errors) == 1 else "Validation failed"
        return JSONResponse(
            status_code=422,
            content=fail(message=message, data={"errors": errors}),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(_request: Request, exc: StarletteHTTPException):
        detail = exc.detail
        if isinstance(detail, str):
            message = detail
        else:
            message = "Request failed"
        return JSONResponse(
            status_code=exc.status_code,
            content=fail(message=message),
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception):
        logger.exception(
            "unhandled_error path=%s method=%s",
            request.url.path,
            request.method,
        )
        return JSONResponse(
            status_code=500,
            content=fail(message="Internal server error"),
        )

    @app.get("/")
    async def root():
        return {
            "success": True,
            "message": settings.app_name,
            "data": {"version": settings.app_version},
        }

    app.include_router(api_router, prefix=settings.api_prefix)
    return app


app = create_app()
