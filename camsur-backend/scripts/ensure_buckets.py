"""
Ensure Supabase Storage buckets exist for Camsur.

- camsur-media (private): user uploads + generation outputs
- assets bucket (public): catalog / banner / tool marketing images

Usage:
  python scripts/ensure_buckets.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.config import get_settings  # noqa: E402
from app.db.supabase import get_supabase  # noqa: E402


def _ensure_bucket(client, bucket_id: str, *, public: bool) -> str:
    try:
        existing = client.storage.get_bucket(bucket_id)
        # get_bucket returns SyncBucket; public flag may be attribute or dict-like
        is_public = getattr(existing, "public", None)
        return f"exists public={is_public}"
    except Exception:
        client.storage.create_bucket(
            bucket_id,
            options={
                "public": public,
                "file_size_limit": 10 * 1024 * 1024,
                "allowed_mime_types": ["image/jpeg", "image/png", "image/webp", "image/jpg"],
            },
        )
        return "created"


def main() -> None:
    settings = get_settings()
    client = get_supabase()

    media = _ensure_bucket(client, settings.media_bucket, public=False)
    assets = _ensure_bucket(client, settings.assets_bucket, public=True)

    print(f"media bucket '{settings.media_bucket}': {media}")
    print(f"assets bucket '{settings.assets_bucket}': {assets}")
    print("Done. Keep media private; keep assets public for catalog images.")


if __name__ == "__main__":
    main()
