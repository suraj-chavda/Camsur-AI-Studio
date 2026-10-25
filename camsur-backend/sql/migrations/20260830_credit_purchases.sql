-- Credit top-up purchases + profitability controls
-- Safe to re-run. Top-ups only (not subscriptions).

-- Profitability knobs on singleton settings
alter table credit_settings
  add column if not exists provider_cost_cents_per_credit int;

alter table credit_settings
  add column if not exists min_gross_margin_bps int;

update credit_settings
set
  provider_cost_cents_per_credit = coalesce(provider_cost_cents_per_credit, 1),
  min_gross_margin_bps = coalesce(min_gross_margin_bps, 2000),
  updated_at = now()
where id = 1;

alter table credit_settings
  alter column provider_cost_cents_per_credit set default 1;

alter table credit_settings
  alter column min_gross_margin_bps set default 2000;

alter table credit_settings
  alter column provider_cost_cents_per_credit set not null;

alter table credit_settings
  alter column min_gross_margin_bps set not null;

-- Purchase orders (one row per top-up attempt)
create table if not exists credit_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  package_slug text not null,
  package_name text not null,
  credits int not null check (credits > 0),
  price_amount_cents int not null check (price_amount_cents > 0),
  currency text not null default 'USD',
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed', 'cancelled')),
  provider text not null default 'manual',
  provider_ref text,
  idempotency_key text not null,
  credit_transaction_id uuid,
  failure_reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create unique index if not exists credit_purchases_idempotency_uidx
  on credit_purchases (idempotency_key);

create index if not exists credit_purchases_user_created_idx
  on credit_purchases (user_id, created_at desc);

create index if not exists credit_purchases_status_idx
  on credit_purchases (status, created_at desc);

alter table credit_purchases enable row level security;

drop policy if exists credit_purchases_select_own on credit_purchases;
create policy credit_purchases_select_own on credit_purchases
  for select
  using (auth.uid() = user_id);

-- Atomic top-up grant booked as type=purchase (not subscription)
create or replace function purchase_user_credits(
  p_user_id uuid,
  p_amount int,
  p_reason text default 'package_topup',
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
) returns credit_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := coalesce(p_idempotency_key, 'purchase:' || gen_random_uuid()::text);
  v_balance int;
  v_new_balance int;
  v_min_topup int;
  v_max_topup int;
  v_max_balance int;
  v_tx credit_transactions%rowtype;
begin
  if p_amount <= 0 then
    raise exception 'credit_amount_must_be_positive';
  end if;

  select * into v_tx from credit_transactions where idempotency_key = v_key;
  if found then
    return v_tx;
  end if;

  select min_topup_credits, max_topup_credits, max_balance_credits
  into v_min_topup, v_max_topup, v_max_balance
  from credit_settings
  where id = 1;

  if p_amount < v_min_topup then
    raise exception 'topup_below_minimum';
  end if;

  if p_amount > v_max_topup then
    raise exception 'topup_above_maximum';
  end if;

  insert into credit_accounts (user_id, balance)
  values (p_user_id, 0)
  on conflict (user_id) do nothing;

  select balance into v_balance
  from credit_accounts
  where user_id = p_user_id
  for update;

  if not found then
    raise exception 'credit_account_not_found';
  end if;

  v_new_balance := v_balance + p_amount;

  if v_new_balance > v_max_balance then
    raise exception 'credit_balance_limit_exceeded';
  end if;

  update credit_accounts
  set balance = v_new_balance,
      updated_at = now()
  where user_id = p_user_id;

  insert into credit_transactions (
    user_id,
    amount,
    balance_after,
    type,
    reason,
    idempotency_key,
    metadata
  )
  values (
    p_user_id,
    p_amount,
    v_new_balance,
    'purchase',
    p_reason,
    v_key,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

revoke execute on function purchase_user_credits(uuid, int, text, text, jsonb) from public;
revoke execute on function purchase_user_credits(uuid, int, text, text, jsonb) from anon;
revoke execute on function purchase_user_credits(uuid, int, text, text, jsonb) from authenticated;
grant execute on function purchase_user_credits(uuid, int, text, text, jsonb) to service_role;

notify pgrst, 'reload schema';
