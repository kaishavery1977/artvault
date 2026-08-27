-- Harden ArtVault — storage RLS + atomic role/revoke
-- Apply: supabase db push

-- A) Storage RLS for av-* buckets — MUST be set via Dashboard → Storage → Policies
-- (alter table storage.objects requires owner, fails via db push)
-- Create in Dashboard: bucket av-profile/paintings/documents, public=false,
-- then add 4 policies on storage.objects for authenticated:
--   using (bucket_id in ('av-profile','av-paintings','av-documents') and auth.uid()::text = (storage.foldername(name))[1])
-- See supabase/storage_policies.sql for the exact SQL to paste in Dashboard SQL editor.

-- B) Atomic revoke / update_role to close read-then-write races
create or replace function revoke_user_atomic(target_uid text, target_email text, target_name text, old_role text)
returns void language plpgsql security definer as $$
begin
  if auth_user_role() <> 'admin' then raise exception 'not admin'; end if;
  insert into public.revoked("uid","email","displayName","role","byUid","byEmail")
    values (target_uid, target_email, target_name, old_role, auth.uid()::text, (select "email" from public.users where "uid"=auth.uid()::text))
    on conflict ("uid") do nothing;
  delete from public.users where "uid"=target_uid;
  insert into public.role_audit("uid","byUid","byEmail","oldRole","newRole")
    values (target_uid, auth.uid()::text, (select "email" from public.users where "uid"=auth.uid()::text), old_role, 'revoked');
end; $$;

create or replace function update_role_atomic(target_uid text, new_role text)
returns void language plpgsql security definer as $$
declare cur text; begin
  if auth_user_role() <> 'admin' or target_uid = auth.uid()::text then raise exception 'forbidden'; end if;
  select "role" into cur from public.users where "uid"=target_uid for update;
  update public.users set "role"=new_role where "uid"=target_uid;
  insert into public.role_audit values (uuid_generate_v4(), target_uid, auth.uid()::text, (select "email" from public.users where "uid"=auth.uid()::text), cur, new_role, now());
end; $$;

-- C) Constraints
alter table public.users drop constraint if exists role_check;
alter table public.users add constraint role_check check ("role" in ('admin','curator','viewer'));
alter table public.users drop constraint if exists plan_check;
alter table public.users add constraint plan_check check ("plan" in ('free','pro'));

NOTIFY pgrst, 'reload schema';
