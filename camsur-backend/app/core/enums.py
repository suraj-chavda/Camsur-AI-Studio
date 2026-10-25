"""Shared enums used across the app."""

from enum import Enum


class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"
    CANCELLED = "cancelled"


ALLOWED_STATUS_TRANSITIONS: dict[str, set[str]] = {
    JobStatus.PENDING.value: {
        JobStatus.PROCESSING.value,
        JobStatus.FAILED.value,
        JobStatus.CANCELLED.value,
    },
    JobStatus.PROCESSING.value: {
        JobStatus.COMPLETED.value,
        JobStatus.FAILED.value,
        JobStatus.REFUNDED.value,
    },
    JobStatus.FAILED.value: {JobStatus.REFUNDED.value},
    JobStatus.COMPLETED.value: set(),
    JobStatus.REFUNDED.value: set(),
    JobStatus.CANCELLED.value: set(),
}


class ImageSource(str, Enum):
    CAMERA = "camera"
    UPLOAD = "upload"


class AIProviderName(str, Enum):
    BFL = "bfl"
    # OPENAI = "openai"
    # REPLICATE = "replicate"
