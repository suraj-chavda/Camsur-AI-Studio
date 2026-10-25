-- Admin-controlled "Trending" section for the mobile home/tools screen.
-- Safe to re-run.

alter table tools add column if not exists is_trending boolean not null default false;
alter table tools add column if not exists trending_sort_order int not null default 100;

create index if not exists tools_trending_idx
  on tools (is_trending, trending_sort_order)
  where is_trending = true;

notify pgrst, 'reload schema';
