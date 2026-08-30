-- Storage RLS for av-* buckets — MUST be applied via Supabase Dashboard → SQL Editor (storage.objects owner is supabase_storage_admin, not postgres)
-- Run this in Dashboard SQL Editor if `supabase db push` fails with "must be owner of table objects"

-- Enable RLS (idempotent)
-- alter table storage.objects enable row level security;

-- AV read own
drop policy if exists "av read own" on storage.objects;
create policy "av read own" on storage.objects for select
  using (bucket_id in ('av-profile','av-paintings','av-documents') and (storage.foldername(name))[1] = auth.uid()::text);

-- AV insert own
drop policy if exists "av insert own" on storage.objects;
create policy "av insert own" on storage.objects for insert
  with check (bucket_id in ('av-profile','av-paintings','av-documents') and (storage.foldername(name))[1] = auth.uid()::text);

-- AV update own
drop policy if exists "av update own" on storage.objects;
create policy "av update own" on storage.objects for update
  using (bucket_id in ('av-profile','av-paintings','av-documents') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('av-profile','av-paintings','av-documents') and (storage.foldername(name))[1] = auth.uid()::text);

-- AV delete own
drop policy if exists "av delete own" on storage.objects;
create policy "av delete own" on storage.objects for delete
  using (bucket_id in ('av-profile','av-paintings','av-documents') and (storage.foldername(name))[1] = auth.uid()::text);
