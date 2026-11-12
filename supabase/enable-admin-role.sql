-- Global B2B Trading: enable the trusted administrator profile role.
-- Run after schema.sql and after the administrator has registered/confirmed an Auth account.
-- Safe to re-run. This only changes the role of the configured admin email.

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('buyer', 'seller', 'admin'));

do $$
declare
  v_admin_id uuid;
  v_updated integer;
begin
  select u.id
    into v_admin_id
  from auth.users as u
  where lower(coalesce(u.email, '')) = 'balelali953@gmail.com'
  limit 1;

  if v_admin_id is null then
    raise exception 'Administrator Auth account not found. Register and confirm the configured admin account, then run this migration again.';
  end if;

  update public.profiles
     set role = 'admin'
   where id = v_admin_id;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Administrator profile not found. Check the Auth profile-creation trigger before retrying.';
  end if;
end;
$$;
