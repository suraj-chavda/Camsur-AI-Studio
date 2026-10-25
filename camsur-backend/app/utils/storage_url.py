"""Helpers for Supabase Storage object paths and URL allowlisting."""

from __future__ import annotations

import re
from urllib.parse import unquote, urlparse

from app.config import Settings

_USER_MEDIA_RE = re.compile(
    r"^users/[0-9a-fA-F-]{36}/(uploads|outputs)/[A-Za-z0-9._-]+$"
)


def storage_host(settings: Settings) -> str:
    return urlparse(settings.supabase_url).netloc.lower()


def is_relative_object_path(value: str) -> bool:
    cleaned = value.strip()
    if not cleaned or "://" in cleaned or cleaned.startswith("//"):
        return False
    if cleaned.startswith("/") or ".." in cleaned.split("/"):
        return False
    return True


def extract_object_ref(value: str, settings: Settings) -> tuple[str, str] | None:
    """Return (bucket, object_path) when value points at our storage."""
    raw = (value or "").strip()
    if not raw:
        return None

    if is_relative_object_path(raw):
        return settings.media_bucket, raw.lstrip("/")

    parsed = urlparse(raw)
    if parsed.scheme not in {"http", "https"}:
        return None

    host = parsed.netloc.lower()
    expected = storage_host(settings)
    if not expected or host != expected:
        return None

    parts = [unquote(part) for part in parsed.path.split("/") if part]
    try:
        object_idx = parts.index("object")
    except ValueError:
        return None

    if len(parts) < object_idx + 3:
        return None

    bucket = parts[object_idx + 2]
    object_path = "/".join(parts[object_idx + 3 :])
    if not object_path or ".." in object_path.split("/"):
        return None

    allowed_buckets = {settings.media_bucket, settings.assets_bucket}
    if bucket not in allowed_buckets:
        return None

    return bucket, object_path


def is_allowed_input_image(value: str, settings: Settings) -> bool:
    ref = extract_object_ref(value, settings)
    if not ref:
        return False
    bucket, path = ref
    if bucket != settings.media_bucket:
        return False
    if path.startswith("uploads/") or path.startswith("outputs/"):
        return True
    return bool(_USER_MEDIA_RE.match(path))
