-- Per-tool input image bounds (hard global cap: 5).
alter table tools add column if not exists min_input_images int not null default 1;
alter table tools add column if not exists max_input_images int not null default 1;

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
