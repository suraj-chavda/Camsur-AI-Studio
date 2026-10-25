-- Optional admin-uploaded style/reference images per tool (e.g. a sample
-- Ghibli frame, a sample oil painting) — used ONLY to steer visual style
-- (technique, mood, color, rendering), never identity/background. Distinct
-- from a user's own uploaded photo(s) and from "together"'s multi-person
-- identity references.
alter table tools add column if not exists style_reference_urls jsonb not null default '[]'::jsonb;
