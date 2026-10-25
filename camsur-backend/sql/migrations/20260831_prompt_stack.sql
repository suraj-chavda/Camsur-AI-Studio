-- Per-tool prompt composition (named layers from data/tools.yaml → runtime).
alter table tools add column if not exists prompt_stack jsonb;
alter table tools add column if not exists iterate_layer text;
