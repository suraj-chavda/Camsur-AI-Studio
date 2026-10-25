-- Storage policies for private media + public assets.
-- Run in Supabase SQL Editor after scripts/ensure_buckets.py.
-- Replace bucket ids if your .env uses different names.

-- Private media: no direct anon/authenticated object access.
-- Access is via backend service_role uploads + create_signed_url.

drop policy if exists "camsur_media_no_public_select" on storage.objects;
drop policy if exists "camsur_media_service_all" on storage.objects;
drop policy if exists "camsur_assets_public_read" on storage.objects;

-- Deny authenticated/anon writes on media (service_role bypasses RLS).
create policy "camsur_media_no_public_select"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'camsur-media' and false);

-- Public catalog assets remain readable.
create policy "camsur_assets_public_read"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'camsur-backend-images');
