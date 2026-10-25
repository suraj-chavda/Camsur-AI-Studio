"""Upload validation with dimension / decompression guards."""

from __future__ import annotations

import io
import uuid

from fastapi import UploadFile
from PIL import Image, ImageFile, UnidentifiedImageError

from app.config import Settings, get_settings
from app.core.exceptions import ValidationError
from app.core.logging import get_logger

ImageFile.LOAD_TRUNCATED_IMAGES = False

logger = get_logger(__name__)

ALLOWED_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
EXT_BY_FORMAT = {
    "JPEG": ".jpg",
    "PNG": ".png",
    "WEBP": ".webp",
}


async def read_upload(file: UploadFile, settings: Settings | None = None) -> bytes:
    """Validate bytes by content, not client Content-Type alone."""
    cfg = settings or get_settings()
    max_bytes = cfg.max_upload_mb * 1024 * 1024

    data = await file.read()
    if not data:
        raise ValidationError("Empty file")
    if len(data) > max_bytes:
        raise ValidationError(f"Image must be under {cfg.max_upload_mb}MB")

    Image.MAX_IMAGE_PIXELS = cfg.max_image_pixels
    try:
        with Image.open(io.BytesIO(data)) as img:
            img.verify()
        with Image.open(io.BytesIO(data)) as img:
            width, height = img.size
            fmt = (img.format or "").upper()
            # Force load to catch truncated / bomb payloads
            img.load()
    except Image.DecompressionBombError as exc:
        raise ValidationError("Image dimensions are too large") from exc
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise ValidationError("Invalid image file") from exc

    if fmt not in EXT_BY_FORMAT:
        raise ValidationError("Only JPEG, PNG, or WebP images are allowed")
    if width > cfg.max_image_width or height > cfg.max_image_height:
        raise ValidationError(
            f"Image dimensions must be at most {cfg.max_image_width}x{cfg.max_image_height}"
        )
    if width * height > cfg.max_image_pixels:
        raise ValidationError("Image has too many pixels")

    # Client Content-Type is advisory only; real format was verified above.
    # TEMP DEBUG (remove once mobile/desktop identity-preservation parity is
    # confirmed): compares what the client claims vs. what the bytes actually
    # are, so a mobile-side re-encode/mislabel would show up here.
    logger.info(
        "upload_validated client_content_type=%s detected_format=%s "
        "width=%s height=%s bytes=%s",
        file.content_type,
        fmt,
        width,
        height,
        len(data),
    )
    return data


def detect_image_format(data: bytes) -> str:
    with Image.open(io.BytesIO(data)) as img:
        fmt = (img.format or "").upper()
    if fmt not in EXT_BY_FORMAT:
        raise ValidationError("Only JPEG, PNG, or WebP images are allowed")
    return fmt


def make_user_object_name(
    user_id: str,
    kind: str,
    *,
    generation_id: str | None = None,
    image_format: str = "JPEG",
) -> str:
    """
    Server-owned path. Never accept client paths.

    users/{user_id}/uploads/{uuid}.jpg
    users/{user_id}/outputs/{generation_id}.jpg
    """
    if kind not in {"uploads", "outputs"}:
        raise ValidationError("Invalid storage folder")
    if ".." in user_id or "/" in user_id or "\\" in user_id:
        raise ValidationError("Invalid user id for storage path")

    ext = EXT_BY_FORMAT.get(image_format.upper(), ".jpg")
    if kind == "outputs" and generation_id:
        if ".." in generation_id or "/" in generation_id:
            raise ValidationError("Invalid generation id for storage path")
        return f"users/{user_id}/outputs/{generation_id}{ext}"
    return f"users/{user_id}/{kind}/{uuid.uuid4().hex}{ext}"
