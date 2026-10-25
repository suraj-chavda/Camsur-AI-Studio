# Camsur AI Studio — Backend Architecture

This document describes the **actual** architecture of `camsur-backend` after the consistency pass. Follow these conventions when adding features.

## Stack

- **FastAPI** HTTP API under `/api/v1`
- **Supabase** Auth + Postgres (PostgREST) + Storage
- **BFL FLUX** image editing (`app/providers`)
- Credits ledger via **Postgres RPCs** (`grant_user_credits`, `spend_user_credits`, `refund_user_credits`)

## Layout

```text
app/
  main.py              # app factory, middleware, exception handlers
  config.py            # pydantic-settings
  dependencies.py      # FastAPI Depends wiring
  core/                # enums, exceptions, response envelope, logging
  db/                  # Supabase client helpers
  middleware/          # rate limiting
  routes/              # thin HTTP adapters (*_route.py)
  schemas/             # Pydantic request/response models
  services/            # business logic (*_service.py)
  providers/           # external AI providers
  utils/               # focused helpers (images, prompts, storage URLs)
sql/                   # schema + RLS + storage policies
scripts/               # ops (schema, credits, audit)
tests/                 # pytest (no live Supabase required for unit tests)
```

## Request flow

```text
HTTP → RateLimitMiddleware → Route
     → Depends (CurrentUser / services)
     → Service method
     → Supabase client (usually via asyncio.to_thread)
       and/or Provider (async httpx)
     → ok() / AppError → fail()
```

Routes stay thin: parse input, call one service method, return `ok(...)`.

## Feature pattern

When adding a domain feature:

1. Add or extend schemas in `app/schemas/<domain>_schema.py`
2. Put business rules in `app/services/<domain>_service.py`
3. Expose HTTP in `app/routes/<domain>_route.py`
4. Wire the service in `app/dependencies.py`
5. Include the router in `app/routes/api.py`
6. Add focused tests for pure helpers / envelopes

Do **not** introduce repositories, generic CRUD bases, or a second response format.

## Responses

All JSON errors and successes use:

```json
{ "success": true|false, "message": "...", "data": ... }
```

- Success: `ok(data=..., message=...)`
- Business errors: raise `AppError` subclasses (`ValidationError` 422, `UnauthorizedError` 401, `InsufficientCreditsError` 402, `NotFoundError` 404, `GenerationFailedError` 502, …)
- Request validation and unhandled exceptions are mapped to the same envelope in `main.py`

## Auth

- Email/password via Supabase Auth
- Google/Apple: mobile app does native sign-in, sends the ID token to `POST /auth/social`
  (`provider`, `id_token`, optional `access_token`/`nonce`), which calls Supabase's
  `sign_in_with_id_token` server-side — same `AuthOut` shape as `/auth/login`. Requires
  the Google/Apple providers to be configured in the Supabase dashboard (external to this repo).
- Every login path (`register`/`login`/`social_login`) upserts the `public.users` profile
  row and ensures a `credit_accounts` row exists — see `AuthService._upsert_profile`.
  `display_name` falls back to one derived from the email local-part if the client/provider
  gives none (see `_derive_display_name`).
- Protected routes depend on `CurrentUserDep` (Bearer token)
- Shared Supabase service client must never call `sign_in` (login uses `new_auth_client()`)

## Credits

- Balance lives in `credit_accounts`
- Spend/refund/grant only through SQL RPCs (atomic + idempotent)
- Ensure accounts via `CreditService.ensure_account` (auth uses this too)

## Storage

- **Media bucket** (private): `uploads/`, `outputs/` — signed URLs
- **Assets bucket** (public): catalog/banner/tool images
- Generation `input_image_url` must resolve to Camsur media (`uploads/` or `outputs/`)

## Configuration

- Runtime config: `app/config.py` + `.env`
- Ops DB URL: `SUPABASE_DB_URL` / `Settings.supabase_db_url`
- Production: `DEBUG=false`, `ENVIRONMENT=production`, explicit `CORS_ORIGINS`

## Logging

Use `app.core.logging.get_logger(__name__)`.

Log operational events (generation start/fail, provider errors). Never log passwords, tokens, API keys, or full signed URLs with secrets when avoidable.

## Credits & generations

See `docs/CREDIT_SYSTEM.md`, `docs/GENERATION_LIFECYCLE.md`, `docs/STORAGE_LIFECYCLE.md`,
`docs/COST_CONTROLS.md`.

- Credits are integers; money uses `Decimal`
- Tool prices come from DB (`tools.credit_cost`), never from the client
- Optional `idempotency_key`; spend/refund RPCs are idempotent
- Default POST is sync; `X-Async: true` returns pending and processes in background
- Storage retention is operational (no storage subscription / no storage credits)

## What not to add

- Clean Architecture / Hexagonal / CQRS for this app size
- Generic BaseRepository / BaseService
- A second error JSON shape
- Business logic inside route handlers
- Silent `except Exception: pass` without a documented reason
