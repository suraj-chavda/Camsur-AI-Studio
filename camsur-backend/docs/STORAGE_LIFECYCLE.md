"""
# Storage Lifecycle

Camsur does **not** sell a storage plan.

| Asset | Path | Retention env | Credits |
| --- | --- | --- | --- |
| Upload | `users/{user_id}/uploads/...` | `UPLOAD_RETENTION_DAYS` (default 30) | none |
| Output | `users/{user_id}/outputs/...` | `OUTPUT_RETENTION_DAYS` (default 90) | none |
| Saved output | same | `SAVED_OUTPUT_RETENTION_DAYS` (0=keep) | none |
| Catalog | assets bucket | permanent | none |

Cleanup logic lives in `app/services/media_cleanup_service.py::MediaCleanupService`, shared
by the manual script and an automatic run:

```bash
python scripts/cleanup_expired_media.py          # dry-run
python scripts/cleanup_expired_media.py --yes
```

It also runs automatically every `BACKGROUND_JOB_INTERVAL_SEC` (default 6h) via the
in-process background loop (`app/core/background_jobs.py`) — nothing needs to remember
to run it manually anymore. Disable with `BACKGROUND_JOBS_ENABLED=false`.

After a successful delete, `generations.input_purged_at` / `output_purged_at` is stamped
so the row is never re-scanned and clients stop trying to sign a URL for a deleted object
(`GenerationService._to_out` skips signing once the matching `*_purged_at` is set). The DB
row and its (now-invalid) `input_image_url`/`output_image_url` are otherwise left intact.

Deleting expired media **never refunds** credits.
User `DELETE /generations/{id}` soft-deletes and removes media; **no refund**.

**Known limitation**: `iterate()` can reference a root generation's original upload path
many versions later via `ORIGIN_SETTINGS_KEY`. A long-lived version chain could still have
its root input purged by the 30-day upload retention independent of `is_saved` on the
current version. Not solved yet — no dependency tracking across the version chain exists;
revisit if this becomes a real problem.
