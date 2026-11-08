-- Global B2B Trading: Admin User Management
-- Adds marketplace-level suspension without deleting accounts or changing Auth credentials.
-- Safe to run more than once.

alter table public.profiles
  add column if not exists account_status text not null default 'active';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_account_status_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_account_status_check
      check (account_status in ('active', 'suspended'));
  end if;
end;
$$;

drop policy if exists "Admin can view all marketplace users" on public.profiles;
create policy "Admin can view all marketplace users"
on public.profiles
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
  and role in ('buyer', 'seller')
);

create or replace function public.admin_set_user_status(
  p_user_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to manage marketplace users';
  end if;

  if p_status not in ('active', 'suspended') then
    raise exception 'Invalid account status';
  end if;

  update public.profiles
  set account_status = p_status
  where id = p_user_id
    and role in ('buyer', 'seller');

  if not found then
    raise exception 'Buyer or seller account not found';
  end if;
end;
$$;

revoke all on function public.admin_set_user_status(uuid, text) from public;
grant execute on function public.admin_set_user_status(uuid, text) to authenticated;
