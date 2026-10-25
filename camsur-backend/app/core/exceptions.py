"""Custom app exceptions."""

from typing import Any


class AppError(Exception):
    """Base app error."""

    def __init__(
        self,
        message: str,
        status_code: int = 400,
        data: Any = None,
    ):
        self.message = message
        self.status_code = status_code
        self.data = data
        super().__init__(message)


class NotFoundError(AppError):
    def __init__(self, message: str = "Resource not found"):
        super().__init__(message, status_code=404)


class ValidationError(AppError):
    def __init__(self, message: str = "Invalid request"):
        super().__init__(message, status_code=422)


class UnauthorizedError(AppError):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(message, status_code=401)


class InsufficientCreditsError(AppError):
    def __init__(self, message: str = "Insufficient credits"):
        super().__init__(message, status_code=402)


class ForbiddenError(AppError):
    def __init__(self, message: str = "Forbidden"):
        super().__init__(message, status_code=403)


class AIProviderError(AppError):
    def __init__(
        self,
        message: str = "AI generation failed",
        provider_request_id: str | None = None,
    ):
        super().__init__(message, status_code=502)
        # Set when the provider job was actually submitted before failing — signals
        # real provider cost was likely incurred even though the generation failed.
        self.provider_request_id = provider_request_id


class GenerationFailedError(AppError):
    """Generation row was saved as failed; return non-200 to the client."""

    def __init__(self, message: str = "Generation failed", data: Any = None):
        super().__init__(message, status_code=502, data=data)


class ServiceUnavailableError(AppError):
    def __init__(self, message: str = "Service temporarily unavailable"):
        super().__init__(message, status_code=503)


class RateLimitedError(AppError):
    def __init__(self, message: str = "Rate limit exceeded"):
        super().__init__(message, status_code=429)
