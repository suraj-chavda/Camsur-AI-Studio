"""Simple in-memory sliding-window rate limiter.

Fine for a single API process. For multi-instance production, replace with
Redis / Cloudflare / API gateway limits.
"""

from __future__ import annotations

import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config import Settings
from app.core.response import fail


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, settings: Settings):
        super().__init__(app)
        self.settings = settings
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    async def dispatch(self, request: Request, call_next):
        if not self.settings.rate_limit_enabled:
            return await call_next(request)

        if request.method == "OPTIONS":
            return await call_next(request)

        path = request.url.path
        prefix = self.settings.api_prefix.rstrip("/")
        if not path.startswith(prefix):
            return await call_next(request)

        client_ip = _client_ip(request)
        now = time.monotonic()
        window = self.settings.rate_limit_window_sec

        checks: list[tuple[str, int]] = [
            (f"ip:{client_ip}", self.settings.rate_limit_ip_per_minute),
        ]

        relative = path[len(prefix) :]
        if relative in {"/auth/login", "/auth/register"}:
            checks.append(
                (f"auth:{client_ip}:{relative}", self.settings.rate_limit_auth_per_minute)
            )
        elif relative == "/uploads/image":
            checks.append(
                (f"upload:{client_ip}", self.settings.rate_limit_upload_per_minute)
            )
        elif relative in {"/generations", "/generations/from-photo"}:
            user_key = _bearer_fingerprint(request) or client_ip
            checks.append(
                (
                    f"generate:{user_key}",
                    self.settings.rate_limit_generate_per_minute,
                )
            )

        for key, limit in checks:
            if self._is_limited(key, now, window, limit):
                return JSONResponse(
                    status_code=429,
                    content=fail(message="Rate limit exceeded. Try again shortly."),
                    headers={"Retry-After": str(window)},
                )

        return await call_next(request)

    def _is_limited(self, key: str, now: float, window: int, limit: int) -> bool:
        with self._lock:
            bucket = self._hits[key]
            cutoff = now - window
            while bucket and bucket[0] < cutoff:
                bucket.popleft()
            if len(bucket) >= limit:
                return True
            bucket.append(now)
            return False


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip() or "unknown"
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def _bearer_fingerprint(request: Request) -> str | None:
    auth = request.headers.get("authorization") or ""
    if not auth.lower().startswith("bearer "):
        return None
    token = auth.split(" ", 1)[1].strip()
    if not token:
        return None
    # Avoid storing full JWTs in the limiter map.
    return token[-24:]
