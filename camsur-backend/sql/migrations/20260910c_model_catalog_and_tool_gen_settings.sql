-- Lets the admin panel switch the active FLUX model without a redeploy, and
-- auto-recompute tool pricing from that model's real $/MP cost + the
-- existing profitability margin (credit_settings.min_gross_margin_bps).

-- One row per selectable model with its $/megapixel cost. additional_mp_usd
-- and input_mp_usd aren't individually published by BFL per model (only a
-- "from $X" first-MP starting price is) — they're estimated here at the
-- same ratio (half of first_mp_usd) BFL's own pricing already implies for
-- the Pro tier (0.03 / 0.015 / 0.015, already used in app/config.py).
-- Verify against the BFL billing dashboard before high-volume production use.
create table if not exists bfl_model_catalog (
  slug text primary key,
  label text not null,
  output_first_mp_usd numeric not null check (output_first_mp_usd >= 0),
  output_additional_mp_usd numeric not null check (output_additional_mp_usd >= 0),
  input_mp_usd numeric not null check (input_mp_usd >= 0),
  is_available boolean not null default true,
  sort_order int not null default 100,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into bfl_model_catalog (slug, label, output_first_mp_usd, output_additional_mp_usd, input_mp_usd, sort_order, notes)
values
  ('flux-2-pro', 'FLUX.2 Pro', 0.03, 0.015, 0.015, 10, 'Production standard — best cost/quality balance.'),
  ('flux-2-flex', 'FLUX.2 Flex', 0.05, 0.025, 0.025, 20, 'Developer-tunable variant.'),
  ('flux-2-max', 'FLUX.2 Max', 0.07, 0.035, 0.035, 30, 'Highest precision editing, highest cost.'),
  ('flux-2-klein-9b', 'FLUX.2 Klein 9B', 0.015, 0.0075, 0.0075, 40, 'Cost-efficient, smaller model.'),
  ('flux-2-klein-4b', 'FLUX.2 Klein 4B', 0.014, 0.007, 0.007, 50, 'Cheapest, smallest model.')
on conflict (slug) do nothing;

-- Singleton (id=1) like credit_settings — the one active model for the whole app.
create table if not exists ai_provider_settings (
  id int primary key default 1 check (id = 1),
  active_model text not null default 'flux-2-pro' references bfl_model_catalog (slug),
  updated_at timestamptz not null default now()
);

insert into ai_provider_settings (id, active_model)
values (1, 'flux-2-pro')
on conflict (id) do nothing;

-- Per-tool BFL generation parameters (mirrors the BFL playground fields) —
-- same "each tool owns its own values" pattern already used for
-- width/height/credit_cost, rather than one global set of knobs.
alter table tools add column if not exists guidance numeric not null default 10;
alter table tools add column if not exists steps int not null default 50;
alter table tools add column if not exists seed int; -- null = random
alter table tools add column if not exists safety_tolerance int not null default 0;
alter table tools add column if not exists prompt_upsampling boolean not null default true;
alter table tools add column if not exists output_format text not null default 'jpeg';

alter table tools alter column width set default 960;
alter table tools alter column height set default 960;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'tools_steps_bounds') then
    alter table tools add constraint tools_steps_bounds check (steps between 1 and 50) not valid;
    alter table tools validate constraint tools_steps_bounds;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'tools_safety_tolerance_bounds') then
    alter table tools add constraint tools_safety_tolerance_bounds check (safety_tolerance between 0 and 5) not valid;
    alter table tools validate constraint tools_safety_tolerance_bounds;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'tools_output_format_valid') then
    alter table tools add constraint tools_output_format_valid check (output_format in ('jpeg', 'png')) not valid;
    alter table tools validate constraint tools_output_format_valid;
  end if;
end $$;
