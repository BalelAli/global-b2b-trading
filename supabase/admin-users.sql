-- Global B2B Trading: Admin User Management with status-change audit history
-- Safe to run more than once. Existing buyer/seller data is preserved.

alter table public.profiles
  add column if not exists account_status text not null default 'active';

do $$
begin
  if not exists (
    select 1 from pg_constraint
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

-- Private audit table: only the security-definer admin RPCs can access it.
create table if not exists public.admin_user_status_events (
  id bigint generated always as identity primary key,
  actor_email text not null,
  target_user_id uuid not null,
  previous_status text not null,
  new_status text not null,
  changed_at timestamptz not null default now()
);

alter table public.admin_user_status_events enable row level security;
revoke all on table public.admin_user_status_events from anon, authenticated;

create or replace function public.admin_set_user_status(
  p_user_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_status text;
  v_actor_email text;
begin
  v_actor_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  if v_actor_email <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to manage marketplace users';
  end if;

  if p_status not in ('active', 'suspended') then
    raise exception 'Invalid account status';
  end if;

  select coalesce(p.account_status, 'active')
    into v_old_status
  from public.profiles as p
  where p.id = p_user_id
    and p.role in ('buyer', 'seller')
  for update;

  if not found then
    raise exception 'Buyer or seller account not found';
  end if;

  if v_old_status <> p_status then
    update public.profiles
      set account_status = p_status
      where id = p_user_id;

    insert into public.admin_user_status_events
      (actor_email, target_user_id, previous_status, new_status)
    values
      (v_actor_email, p_user_id, v_old_status, p_status);
  end if;
end;
$$;

revoke all on function public.admin_set_user_status(uuid, text) from public;
grant execute on function public.admin_set_user_status(uuid, text) to authenticated;

create or replace function public.admin_list_user_status_events()
returns table (
  event_id bigint,
  actor_email text,
  target_user_id uuid,
  target_name text,
  previous_status text,
  new_status text,
  changed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view account status history';
  end if;

  return query
    select e.id, e.actor_email, e.target_user_id,
           coalesce(p.full_name, p.company_name, 'User account')::text,
           e.previous_status, e.new_status, e.changed_at
    from public.admin_user_status_events as e
    left join public.profiles as p on p.id = e.target_user_id
    order by e.changed_at desc, e.id desc
    limit 20;
end;
$$;

revoke all on function public.admin_list_user_status_events() from public;
grant execute on function public.admin_list_user_status_events() to authenticated;
