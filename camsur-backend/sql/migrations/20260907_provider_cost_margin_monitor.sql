-- Per-generation provider cost tracking + dynamic per-tool margin circuit breaker
-- + storage purge bookkeeping. Safe to re-run.

-- Real (estimated) BFL cost incurred for a generation, in USD.
-- NULL means no real provider cost was incurred (failed before submission).
alter table generations
  add column if not exists provider_cost_usd numeric(10, 4);

-- Bookkeeping so cleanup jobs don't leave dangling image references and
-- don't re-scan already-purged rows forever.
alter table generations
  add column if not exists input_purged_at timestamptz;

alter table generations
  add column if not exists output_purged_at timestamptz;

create index if not exists generations_tool_created_idx
  on generations (tool_slug, created_at desc)
  where deleted_at is null;

create index if not exists generations_cost_created_idx
  on generations (created_at)
  where provider_cost_usd is not null;

-- Tool kill-switch audit trail (tools.is_active already exists and is reused
-- as the margin circuit breaker's trip lever — no new state machine).
alter table tools
  add column if not exists disabled_reason text;

alter table tools
  add column if not exists disabled_at timestamptz;

-- Append-only audit trail for the margin monitor: what was computed, whether
-- the breaker fired, and a human-reviewed pricing suggestion. Ops/admin data
-- only — no anon/authenticated policy, service_role bypasses RLS.
create table if not exists tool_margin_snapshots (
  id uuid primary key default gen_random_uuid(),
  tool_slug text not null,
  window_days int not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  generations_count int not null default 0,
  generations_with_cost_count int not null default 0,
  net_credits int not null default 0,
  effective_usd_per_credit numeric(10, 6) not null,
  revenue_usd numeric(12, 4) not null,
  provider_cost_usd numeric(12, 4) not null,
  margin_usd numeric(12, 4) not null,
  suggested_credit_cost int,
  action_taken text not null default 'none'
    check (action_taken in ('none', 'disabled', 'already_disabled', 'insufficient_samples')),
  created_at timestamptz not null default now()
);

create index if not exists tool_margin_snapshots_tool_created_idx
  on tool_margin_snapshots (tool_slug, created_at desc);

alter table tool_margin_snapshots enable row level security;

notify pgrst, 'reload schema';
