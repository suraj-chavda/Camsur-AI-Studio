"""
Cleanup expired user media (uploads/outputs).

NEVER refunds credits.
NEVER deletes catalog assets.
NEVER deletes saved outputs (is_saved=true) unless saved retention is configured.

Shared by scripts/cleanup_expired_media.py (manual/CLI) and the background
maintenance loop (app/core/background_jobs.py).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

from supabase import Client

from app.config import Settings
from app.core.logging import get_logger
from app.services.storage_service import StorageService

logger = get_logger(__name__)


@dataclass
class CleanupStats:
    scanned: int = 0
    expired: int = 0
    deleted: int = 0
    skipped: int = 0
    failed: int = 0


class MediaCleanupService:
    def __init__(self, db: Client, settings: Settings, storage: StorageService):
        self.db = db
        self.settings = settings
        self.storage = storage

    def run(
        self,
        *,
        limit: int = 200,
        dry_run: bool = True,
        on_event: Callable[[str], None] | None = None,
    ) -> CleanupStats:
        now = datetime.now(timezone.utc).isoformat()
        stats = CleanupStats()
        seen_paths: set[str] = set()

        # Rows already purged (*_purged_at set) or currently in-flight are excluded
        # at the query level, so re-running never re-scans the same rows forever.
        input_rows = (
            self.db.table("generations")
            .select("id,status,input_image_url")
            .lte("input_expires_at", now)
            .is_("deleted_at", "null")
            .is_("input_purged_at", "null")
            .eq("is_saved", False)
            .limit(limit)
            .execute()
            .data
            or []
        )
        output_rows = (
            self.db.table("generations")
            .select("id,status,output_image_url")
            .lte("output_expires_at", now)
            .is_("deleted_at", "null")
            .is_("output_purged_at", "null")
            .eq("is_saved", False)
            .limit(limit)
            .execute()
            .data
            or []
        )

        for row in input_rows:
            self._handle(row, "input_image_url", "input_purged_at", seen_paths, stats, dry_run, on_event)
        for row in output_rows:
            self._handle(row, "output_image_url", "output_purged_at", seen_paths, stats, dry_run, on_event)

        return stats

    def _handle(
        self,
        row: dict,
        path_key: str,
        purged_field: str,
        seen_paths: set[str],
        stats: CleanupStats,
        dry_run: bool,
        on_event: Callable[[str], None] | None,
    ) -> None:
        stats.scanned += 1
        path = row.get(path_key)
        if not path or path.startswith("http") or path.startswith("assets/"):
            stats.skipped += 1
            return
        if path in seen_paths:
            stats.skipped += 1
            return
        if row.get("status") in {"pending", "processing"}:
            stats.skipped += 1
            return

        stats.expired += 1
        seen_paths.add(path)
        if dry_run:
            message = f"DRY-RUN would delete {path_key} generation={row['id']} path={path}"
            logger.info("media_cleanup_dry_run field=%s generation_id=%s path=%s", path_key, row["id"], path)
            if on_event:
                on_event(message)
            return

        try:
            self.storage.delete_object(path)
            self.db.table("generations").update(
                {purged_field: datetime.now(timezone.utc).isoformat()}
            ).eq("id", row["id"]).execute()
            stats.deleted += 1
            logger.info("media_cleanup_deleted generation_id=%s path=%s", row["id"], path)
            if on_event:
                on_event(f"DELETED {path}")
        except Exception as exc:
            stats.failed += 1
            logger.warning("media_cleanup_failed generation_id=%s path=%s error=%s", row["id"], path, exc)
            if on_event:
                on_event(f"FAILED {path}: {exc}")
