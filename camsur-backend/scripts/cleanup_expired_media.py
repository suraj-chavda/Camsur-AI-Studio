"""
Cleanup expired user media (uploads/outputs).

NEVER refunds credits.
NEVER deletes catalog assets.
NEVER deletes saved outputs (is_saved=true) unless saved retention is configured.

This is a thin CLI wrapper over app.services.media_cleanup_service.MediaCleanupService
— the same logic also runs automatically every BACKGROUND_JOB_INTERVAL_SEC via the
app's background maintenance loop (see app/core/background_jobs.py).

Usage:
  python scripts/cleanup_expired_media.py          # dry-run (default)
  python scripts/cleanup_expired_media.py --yes    # perform deletes
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.config import get_settings  # noqa: E402
from app.db.supabase import get_supabase  # noqa: E402
from app.services.media_cleanup_service import MediaCleanupService  # noqa: E402
from app.services.storage_service import StorageService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Cleanup expired Camsur media")
    parser.add_argument("--yes", action="store_true", help="Actually delete objects")
    parser.add_argument("--limit", type=int, default=200, help="Max rows to scan")
    args = parser.parse_args()

    settings = get_settings()
    db = get_supabase()
    storage = StorageService(db, settings)
    service = MediaCleanupService(db, settings, storage)

    stats = service.run(limit=args.limit, dry_run=not args.yes, on_event=print)

    print(
        f"Scanned: {stats.scanned}\nExpired: {stats.expired}\nDeleted: {stats.deleted}\n"
        f"Skipped: {stats.skipped}\nFailed: {stats.failed}\nDry-run: {not args.yes}"
    )


if __name__ == "__main__":
    main()
