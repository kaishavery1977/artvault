-- Harden ArtVault — storage RLS + atomic role/revoke
-- Apply: supabase db push

-- A) Storage RLS for av-* buckets (owner folder = auth.uid())
alter table storage.objects enable row level security;
drop policy if exists "av read own" on storage.objects;
drop policy if exists "av insert own" on storage.objects;
drop policy if exists "av update own" on storage.objects;
drop policy if exists "av delete own" on storage.objects;

create policy "av read own" on storage.objects for select to authenticated
  using (bucket_id in ('av-profile','av-paintings','av-documents') and auth.uid()::text = (storage.foldername(name))[1]);
create policy "av insert own" on storage.objects for insert to authenticated
  with check (bucket_id in ('av-profile','av-paintings','av-documents') and auth.uid()::text = (storage.foldername(name))[1]);
create policy "av update own" on storage.objects for update to authenticated
  using (bucket_id in ('av-profile','av-paintings','av-documents') and auth.uid()::text = (storage.foldername(name))[1]);
create policy "av delete own" on storage.objects for delete to authenticated
  using (bucket_id in ('av-profile','av-paintings','av-documents') and auth.uid()::text = (storage.foldername(name))[1]);

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
