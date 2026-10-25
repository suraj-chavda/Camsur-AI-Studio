-- Generation version lineage for feedback iterates.
alter table generations
  add column if not exists parent_generation_id uuid references generations (id) on delete set null;

alter table generations
  add column if not exists root_generation_id uuid references generations (id) on delete set null;

alter table generations
  add column if not exists version_index int not null default 1;

alter table generations
  add column if not exists feedback text;

create index if not exists generations_root_version_idx
  on generations (root_generation_id, version_index)
  where deleted_at is null;

create index if not exists generations_parent_idx
  on generations (parent_generation_id)
  where parent_generation_id is not null;
