-- Run once in Supabase SQL Editor (or re-run safe parts).
-- Storage:
--   SUPABASE_MEDIA_BUCKET  = private (uploads/outputs) — create via scripts/ensure_buckets.py
--   SUPABASE_ASSETS_BUCKET = public  (catalog/banner/tool images)
-- Auth: Email provider enabled. Password auth (OTP later).
-- Backend Secret / service_role key bypasses RLS.

create extension if not exists pgcrypto;

-- App profile row, 1:1 with auth.users
create table if not exists users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  display_name text,
  device_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists credit_accounts (
  user_id uuid primary key references users (id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists credit_packages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  credits int not null check (credits > 0),
  price_amount_cents int not null check (price_amount_cents >= 0),
  currency text not null default 'USD',
  platform text not null default 'manual',
  provider_product_id text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default false,
  sort_order int not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists credit_settings (
  id int primary key default 1 check (id = 1),
  min_topup_credits int not null default 100 check (min_topup_credits > 0),
  max_topup_credits int not null default 2000 check (max_topup_credits >= min_topup_credits),
  max_balance_credits int not null default 10000 check (max_balance_credits >= max_topup_credits),
  updated_at timestamptz not null default now()
);

insert into credit_settings (id, min_topup_credits, max_topup_credits, max_balance_credits)
values (1, 100, 2000, 10000)
on conflict (id) do nothing;

-- Profitability defaults (also applied in credit_purchases migration)
alter table credit_settings
  add column if not exists provider_cost_cents_per_credit int;

alter table credit_settings
  add column if not exists min_gross_margin_bps int;

update credit_settings
set
  provider_cost_cents_per_credit = coalesce(provider_cost_cents_per_credit, 1),
  min_gross_margin_bps = coalesce(min_gross_margin_bps, 2000)
where id = 1;

insert into credit_packages (
  slug,
  name,
  credits,
  price_amount_cents,
  currency,
  platform,
  metadata,
  is_active,
  sort_order
)
values
  (
    'starter_100',
    'Starter Pack',
    100,
    199,
    'USD',
    'manual',
    '{"recommended_for": "testing and light users"}'::jsonb,
    true,
    10
  ),
  (
    'value_300',
    'Value Pack',
    300,
    499,
    'USD',
    'manual',
    '{"recommended_for": "regular users"}'::jsonb,
    true,
    20
  ),
  (
    'pro_750',
    'Pro Pack',
    750,
    999,
    'USD',
    'manual',
    '{"recommended_for": "power users"}'::jsonb,
    true,
    30
  ),
  (
    'max_2000',
    'Max Pack',
    2000,
    2499,
    'USD',
    'manual',
    '{"recommended_for": "high volume"}'::jsonb,
    true,
    40
  )
on conflict (slug) do nothing;

-- Mobile catalog categories. `tools.category` stores this slug.
create table if not exists tool_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  icon text,
  image_url text,
  sort_order int not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Home carousel / promo banners for mobile
create table if not exists app_banners (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  subtitle text not null default '',
  image_url text,
  link_type text not null default 'none',
  link_value text,
  sort_order int not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_banners_active_sort_idx
  on app_banners (is_active, sort_order);

create table if not exists app_onboarding (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  subtitle text not null default '',
  image_url text,
  icon text,
  sort_order int not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_onboarding_active_sort_idx
  on app_onboarding (is_active, sort_order);

create index if not exists tool_categories_active_sort_idx
  on tool_categories (is_active, sort_order);

-- Editable AI tools + Jinja2 prompts/settings (source of truth for the app catalog)
create table if not exists tools (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  category text not null default 'portrait',
  prompt_template text not null,
  prompt_stack jsonb,
  iterate_layer text,
  settings jsonb not null default '[]'::jsonb,
  credit_cost int not null default 1 check (credit_cost >= 0),
  image_url text,
  width int not null check (width >= 64),
  height int not null check (height >= 64),
  is_active boolean not null default true,
  sort_order int not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tools_active_sort_idx
  on tools (is_active, sort_order);

create table if not exists generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  tool_slug text not null,
  source text not null,
  status text not null default 'pending',
  input_image_url text not null,
  output_image_url text,
  style_notes text,
  settings jsonb not null default '{}'::jsonb,
  credit_cost int not null default 0 check (credit_cost >= 0),
  credit_spend_transaction_id uuid,
  credit_refund_transaction_id uuid,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists generations_user_created_idx
  on generations (user_id, created_at desc);

create table if not exists credit_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  generation_id uuid references generations (id) on delete set null,
  tool_slug text,
  amount int not null check (amount <> 0),
  balance_after int not null check (balance_after >= 0),
  type text not null check (type in ('grant', 'spend', 'refund', 'adjustment')),
  reason text,
  idempotency_key text unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists credit_transactions_user_created_idx
  on credit_transactions (user_id, created_at desc);

create index if not exists credit_transactions_generation_idx
  on credit_transactions (generation_id);

-- Migrate old projects from generation_type -> tool_slug
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'generations' and column_name = 'generation_type'
  ) and not exists (
    select 1 from information_schema.columns
    where table_name = 'generations' and column_name = 'tool_slug'
  ) then
    alter table generations rename column generation_type to tool_slug;
  end if;
end $$;

-- Safe migrations for existing projects
alter table tools add column if not exists settings jsonb not null default '[]'::jsonb;
alter table tools add column if not exists credit_cost int not null default 1;
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'tools_credit_cost_nonnegative'
  ) then
    alter table tools add constraint tools_credit_cost_nonnegative check (credit_cost >= 0) not valid;
    alter table tools validate constraint tools_credit_cost_nonnegative;
  end if;
end $$;
alter table tool_categories add column if not exists icon text;
alter table tool_categories add column if not exists image_url text;
alter table tool_categories add column if not exists description text not null default '';
alter table tool_categories add column if not exists sort_order int not null default 100;
alter table tool_categories add column if not exists is_active boolean not null default true;
alter table tools add column if not exists image_url text;
alter table tools add column if not exists min_input_images int not null default 1;
alter table tools add column if not exists max_input_images int not null default 1;
alter table tools add column if not exists prompt_stack jsonb;
alter table tools add column if not exists iterate_layer text;
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'tools_input_images_bounds'
  ) then
    alter table tools
      add constraint tools_input_images_bounds
      check (
        min_input_images >= 1
        and max_input_images >= min_input_images
        and max_input_images <= 5
      ) not valid;
    alter table tools validate constraint tools_input_images_bounds;
  end if;
end $$;
alter table app_banners add column if not exists image_url text;
alter table app_banners add column if not exists subtitle text not null default '';
alter table app_banners add column if not exists link_type text not null default 'none';
alter table app_banners add column if not exists link_value text;
alter table app_banners add column if not exists sort_order int not null default 100;
alter table app_banners add column if not exists is_active boolean not null default true;
alter table generations add column if not exists tool_slug text;
alter table generations add column if not exists settings jsonb not null default '{}'::jsonb;
alter table generations add column if not exists credit_cost int not null default 0;
alter table generations add column if not exists credit_spend_transaction_id uuid;
alter table generations add column if not exists credit_refund_transaction_id uuid;
alter table generations add column if not exists parent_generation_id uuid references generations (id) on delete set null;
alter table generations add column if not exists root_generation_id uuid references generations (id) on delete set null;
alter table generations add column if not exists version_index int not null default 1;
alter table generations add column if not exists feedback text;
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'generations_credit_cost_nonnegative'
  ) then
    alter table generations add constraint generations_credit_cost_nonnegative check (credit_cost >= 0) not valid;
    alter table generations validate constraint generations_credit_cost_nonnegative;
  end if;
end $$;

insert into credit_accounts (user_id, balance)
select id, 0
from users
on conflict (user_id) do nothing;

-- Backfill categories for already-synced tools before adding the FK.
insert into tool_categories (slug, name, sort_order)
select distinct
  category,
  initcap(replace(category, '_', ' ')),
  100
from tools
where category is not null
on conflict (slug) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'tools_category_fkey'
  ) then
    alter table tools
      add constraint tools_category_fkey
      foreign key (category) references tool_categories (slug);
  end if;
end $$;

alter table users enable row level security;
alter table credit_accounts enable row level security;
alter table credit_packages enable row level security;
alter table credit_settings enable row level security;
alter table credit_transactions enable row level security;
alter table tool_categories enable row level security;
alter table app_banners enable row level security;
alter table app_onboarding enable row level security;
alter table tools enable row level security;
alter table generations enable row level security;

create or replace function grant_user_credits(
  p_user_id uuid,
  p_amount int,
  p_reason text default 'manual_topup',
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
) returns credit_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := coalesce(p_idempotency_key, 'grant:' || gen_random_uuid()::text);
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
    'grant',
    p_reason,
    v_key,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

create or replace function spend_user_credits(
  p_user_id uuid,
  p_amount int,
  p_generation_id uuid,
  p_tool_slug text,
  p_idempotency_key text,
  p_metadata jsonb default '{}'::jsonb
) returns credit_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
  v_new_balance int;
  v_tx credit_transactions%rowtype;
begin
  if p_amount <= 0 then
    raise exception 'credit_amount_must_be_positive';
  end if;

  select * into v_tx from credit_transactions where idempotency_key = p_idempotency_key;
  if found then
    return v_tx;
  end if;

  insert into credit_accounts (user_id, balance)
  values (p_user_id, 0)
  on conflict (user_id) do nothing;

  select balance into v_balance
  from credit_accounts
  where user_id = p_user_id
  for update;

  if v_balance < p_amount then
    raise exception 'insufficient_credits';
  end if;

  v_new_balance := v_balance - p_amount;

  update credit_accounts
  set balance = v_new_balance,
      updated_at = now()
  where user_id = p_user_id;

  insert into credit_transactions (
    user_id,
    generation_id,
    tool_slug,
    amount,
    balance_after,
    type,
    reason,
    idempotency_key,
    metadata
  )
  values (
    p_user_id,
    p_generation_id,
    p_tool_slug,
    -p_amount,
    v_new_balance,
    'spend',
    'generation',
    p_idempotency_key,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

create or replace function refund_user_credits(
  p_user_id uuid,
  p_amount int,
  p_generation_id uuid,
  p_tool_slug text,
  p_idempotency_key text,
  p_reason text default 'generation_failed',
  p_metadata jsonb default '{}'::jsonb
) returns credit_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
  v_new_balance int;
  v_tx credit_transactions%rowtype;
begin
  if p_amount <= 0 then
    raise exception 'credit_amount_must_be_positive';
  end if;

  select * into v_tx from credit_transactions where idempotency_key = p_idempotency_key;
  if found then
    return v_tx;
  end if;

  insert into credit_accounts (user_id, balance)
  values (p_user_id, 0)
  on conflict (user_id) do nothing;

  select balance into v_balance
  from credit_accounts
  where user_id = p_user_id
  for update;

  v_new_balance := v_balance + p_amount;

  update credit_accounts
  set balance = v_new_balance,
      updated_at = now()
  where user_id = p_user_id;

  insert into credit_transactions (
    user_id,
    generation_id,
    tool_slug,
    amount,
    balance_after,
    type,
    reason,
    idempotency_key,
    metadata
  )
  values (
    p_user_id,
    p_generation_id,
    p_tool_slug,
    p_amount,
    v_new_balance,
    'refund',
    p_reason,
    p_idempotency_key,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  return v_tx;
end;
$$;

revoke execute on function grant_user_credits(uuid, int, text, text, jsonb) from public;
revoke execute on function grant_user_credits(uuid, int, text, text, jsonb) from anon;
revoke execute on function grant_user_credits(uuid, int, text, text, jsonb) from authenticated;
grant execute on function grant_user_credits(uuid, int, text, text, jsonb) to service_role;

revoke execute on function spend_user_credits(uuid, int, uuid, text, text, jsonb) from public;
revoke execute on function spend_user_credits(uuid, int, uuid, text, text, jsonb) from anon;
revoke execute on function spend_user_credits(uuid, int, uuid, text, text, jsonb) from authenticated;
grant execute on function spend_user_credits(uuid, int, uuid, text, text, jsonb) to service_role;

revoke execute on function refund_user_credits(uuid, int, uuid, text, text, text, jsonb) from public;
revoke execute on function refund_user_credits(uuid, int, uuid, text, text, text, jsonb) from anon;
revoke execute on function refund_user_credits(uuid, int, uuid, text, text, text, jsonb) from authenticated;
grant execute on function refund_user_credits(uuid, int, uuid, text, text, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- RLS policies (defense in depth). Backend service_role bypasses RLS.
-- Direct anon/authenticated clients get read-own / public-catalog only.
-- ---------------------------------------------------------------------------

drop policy if exists users_select_own on users;
create policy users_select_own on users
  for select to authenticated
  using (auth.uid() = id);

drop policy if exists credit_accounts_select_own on credit_accounts;
create policy credit_accounts_select_own on credit_accounts
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists credit_transactions_select_own on credit_transactions;
create policy credit_transactions_select_own on credit_transactions
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists generations_select_own on generations;
create policy generations_select_own on generations
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists credit_packages_select_active on credit_packages;
create policy credit_packages_select_active on credit_packages
  for select to anon, authenticated
  using (is_active = true);

drop policy if exists credit_settings_select on credit_settings;
create policy credit_settings_select on credit_settings
  for select to authenticated
  using (true);

drop policy if exists tools_select_active on tools;
create policy tools_select_active on tools
  for select to anon, authenticated
  using (is_active = true);

drop policy if exists tool_categories_select_active on tool_categories;
create policy tool_categories_select_active on tool_categories
  for select to anon, authenticated
  using (is_active = true);

drop policy if exists app_banners_select_active on app_banners;
create policy app_banners_select_active on app_banners
  for select to anon, authenticated
  using (is_active = true);

drop policy if exists app_onboarding_select_active on app_onboarding;
create policy app_onboarding_select_active on app_onboarding
  for select to anon, authenticated
  using (is_active = true);

-- Refresh Supabase/PostgREST schema cache after column changes
notify pgrst, 'reload schema';
