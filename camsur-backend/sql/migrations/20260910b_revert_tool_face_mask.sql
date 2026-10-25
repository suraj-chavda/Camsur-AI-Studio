-- Reverts 20260910_tool_face_mask.sql (deleted) — the masked-inpainting
-- Fill approach didn't reliably replace background/clothing, so it was
-- dropped in favor of the normal edit endpoint.
alter table tools drop column if exists use_face_mask;
