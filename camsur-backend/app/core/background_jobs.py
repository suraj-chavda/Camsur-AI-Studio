"""
In-process periodic maintenance loop: storage cleanup + margin monitor.

Single long-lived process assumption (no Dockerfile/Procfile implying multiple
replicas today). If ever horizontally scaled, add a pg_try_advisory_lock guard
before running — not needed now. Mirrors the existing asyncio.create_task
fire-and-forget idiom already used for generation processing
(app/routes/generation_route.py::_schedule_process).
"""

from __future__ import annotations

import asyncio

from fastapi import FastAPI

from app.config import get_settings
from app.core.logging import get_logger
from app.db.supabase import get_supabase
from app.services.margin_monitor_service import MarginMonitorService
from app.services.media_cleanup_service import MediaCleanupService
from app.services.storage_service import StorageService

logger = get_logger(__name__)

STARTUP_DELAY_SEC = 30


async def run_periodic_maintenance() -> None:
    settings = get_settings()
    db = get_supabase()
    storage = StorageService(db, settings)

    try:
        await asyncio.sleep(STARTUP_DELAY_SEC)
    except asyncio.CancelledError:
        return

    while True:
        try:
            cleanup = MediaCleanupService(db, settings, storage)
            stats = cleanup.run(limit=200, dry_run=False)
            logger.info(
                "background_media_cleanup scanned=%s expired=%s deleted=%s failed=%s",
                stats.scanned,
                stats.expired,
                stats.deleted,
                stats.failed,
            )
        except Exception:
            logger.exception("background_media_cleanup_failed")

        try:
            monitor = MarginMonitorService(db, settings)
            snapshots = monitor.recompute_and_enforce()
            disabled = [s.tool_slug for s in snapshots if s.action_taken == "disabled"]
            if disabled:
                logger.warning("background_margin_monitor_disabled tools=%s", disabled)
            else:
                logger.info("background_margin_monitor_ok tools_checked=%s", len(snapshots))
        except Exception:
            logger.exception("background_margin_monitor_failed")

        try:
            await asyncio.sleep(settings.background_job_interval_sec)
        except asyncio.CancelledError:
            return


def start_background_jobs(app: FastAPI) -> None:
    settings = get_settings()
    if not settings.background_jobs_enabled:
        logger.info("background_jobs_disabled")
        app.state.background_task = None
        return
    app.state.background_task = asyncio.create_task(run_periodic_maintenance())


async def stop_background_jobs(app: FastAPI) -> None:
    task = getattr(app.state, "background_task", None)
    if task is None:
        return
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
