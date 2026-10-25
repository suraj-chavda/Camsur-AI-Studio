-- Dynamic onboarding slides (same pattern as banners/categories).
-- Safe to re-run.

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

alter table app_onboarding enable row level security;

drop policy if exists app_onboarding_select_active on app_onboarding;
create policy app_onboarding_select_active on app_onboarding
  for select to anon, authenticated
  using (is_active = true);

notify pgrst, 'reload schema';
