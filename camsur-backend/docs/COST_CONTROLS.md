"""
# Cost Controls

| Control | Env | Default |
| --- | --- | --- |
| Kill switch | `AI_GENERATION_ENABLED` | true |
| Maintenance | `GENERATION_MAINTENANCE_MODE` | false |
| Per-user concurrent | `MAX_CONCURRENT_GENERATIONS_PER_USER` | 3 |
| Global active | `MAX_GLOBAL_ACTIVE_GENERATIONS` | 100 |
| Per-user hour/day gens | `MAX_GENERATIONS_PER_USER_PER_*` | 30 / 100 |
| Credit spend caps | `MAX_CREDITS_SPENT_PER_USER_PER_*` | 500 / 2000 |
| Global gens/hour | `MAX_GLOBAL_GENERATIONS_PER_HOUR` | 5000 |
| Upload max | `MAX_UPLOAD_MB` / dimension envs | 10MB / 8192 |
| Dual BFL input | `BFL_DUPLICATE_INPUT_IMAGE` | true (until A/B) |

In-memory HTTP rate limits remain; Redis can replace later without changing routes.

## Real provider cost tracking

`generations.provider_cost_usd` is a real, per-generation estimated cost — FLUX.2 [pro]
tiered megapixel billing: output = `BFL_OUTPUT_FIRST_MP_USD` for the first output MP +
`BFL_OUTPUT_ADDITIONAL_MP_USD` per MP beyond that, plus `BFL_INPUT_MP_USD` per output-MP
per reference image sent (see `estimate_provider_cost_usd`) — persisted on:
- **completed** generations, right after the provider call succeeds
- **submitted-but-failed** generations — a job BFL actually accepted before the
  request later failed (poll/download/host-check error) still likely cost real
  money even though the user's credits are fully refunded

`NULL` means no real cost was incurred (failed before submission, e.g. insufficient
credits, invalid input). See `app/services/pricing_service.py::estimate_provider_cost_usd`
and `GenerationService._process` / `_fail_and_refund`.

## Margin circuit breaker (dynamic, per tool)

`MarginMonitorService` (`app/services/margin_monitor_service.py`) recomputes, every
`BACKGROUND_JOB_INTERVAL_SEC` (default 6h, see `app/core/background_jobs.py`), the
realized margin per tool over a trailing `MARGIN_MONITOR_WINDOW_DAYS` window (default 7):

- Revenue = net spent credits (spend − refund) × a blended real $/credit rate from
  actually completed `credit_purchases` (falls back to the lowest active package's
  price-per-credit if there's no purchase history yet — never an assumed rate).
- Cost = sum of real `provider_cost_usd` for that tool's generations in the window.
- If margin goes negative (with at least `MARGIN_MONITOR_MIN_SAMPLES` generations in
  the window to avoid noise), the tool is auto-disabled: `tools.is_active=false`,
  `disabled_reason='auto_margin_breaker'`. This reuses the existing catalog kill
  switch — no new state machine.
- Every run also writes an audit row to `tool_margin_snapshots`, including a
  human-reviewed `suggested_credit_cost` — pricing itself is never changed
  automatically (see `app/services/pricing_service.py::resolve_generation_pricing`,
  which deliberately stays a flat, DB-driven charge).
- **Re-enabling a disabled tool is always manual**: fix pricing/cost via
  `PATCH /api/v1/admin/tools/{slug}`, then call
  `POST /api/v1/admin/tools/{slug}/reenable` to clear `disabled_reason` and set
  `is_active=true`. Both require an admin-role user (`AdminUserDep`); there's no
  admin UI — call them directly (curl/Postman/etc.).
- **Known limitation**: credits are fungible, so manually-granted/free credits spent
  on a tool are counted as revenue at the blended rate. Fine at small scale; revisit
  if promo-credit volume grows.

Run `python scripts/generation_cost_report.py --days 7` for a human-readable report
using the same real numbers (report-only — never disables a tool).

## Background jobs

One in-process asyncio loop (`app/core/background_jobs.py`, started from
`app/main.py`'s FastAPI `lifespan`) runs storage cleanup and the margin monitor back
to back every `BACKGROUND_JOB_INTERVAL_SEC`. This assumes a single long-lived
process — if ever horizontally scaled, add a `pg_try_advisory_lock` guard before
running (not needed today). Disable entirely with `BACKGROUND_JOBS_ENABLED=false`.

FinOps estimate (not ledger): `BFL_OUTPUT_FIRST_MP_USD` / `BFL_OUTPUT_ADDITIONAL_MP_USD` /
`BFL_INPUT_MP_USD` drive `provider_cost_usd` above and per-tool margin monitoring — still
not used for user credit charging.
