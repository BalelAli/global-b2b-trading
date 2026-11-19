-- Global B2B Trading: admin-controlled Verified Buyer / Verified Seller trust badges.
-- Safe to re-run. Verification is opt-in by administrator only; no private contact information is exposed.

alter table public.profiles
  add column if not exists is_verified boolean not null default false;

create table if not exists public.verification_audit (
  id bigint generated always as identity primary key,
  actor_email text not null,
  target_user_id uuid not null references public.profiles(id) on delete cascade,
  previous_verified boolean not null,
  new_verified boolean not null,
  changed_at timestamptz not null default now()
);
alter table public.verification_audit enable row level security;
revoke all on table public.verification_audit from anon, authenticated;

-- Admin list: includes only non-sensitive profile details, no email or phone.
create or replace function public.admin_list_verification_users()
returns table (
  id uuid,
  role text,
  full_name text,
  company_name text,
  country text,
  is_verified boolean,
  account_status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to manage verification badges';
  end if;
  return query
    select p.id, p.role, p.full_name, p.company_name, p.country,
           p.is_verified, coalesce(p.account_status,'active')::text, p.created_at
    from public.profiles p
    where p.role in ('buyer','seller')
    order by p.created_at desc;
end;
$$;
revoke all on function public.admin_list_verification_users() from public;
grant execute on function public.admin_list_verification_users() to authenticated;

create or replace function public.admin_set_verification(
  p_user_id uuid,
  p_verified boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old boolean;
  v_actor text;
begin
  v_actor := lower(coalesce(auth.jwt() ->> 'email', ''));
  if v_actor <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to change verification';
  end if;
  select p.is_verified into v_old
  from public.profiles p
  where p.id = p_user_id and p.role in ('buyer','seller')
  for update;
  if not found then raise exception 'Buyer or seller account not found'; end if;
  if v_old is distinct from p_verified then
    update public.profiles set is_verified=p_verified where id=p_user_id;
    insert into public.verification_audit(actor_email,target_user_id,previous_verified,new_verified)
    values(v_actor,p_user_id,v_old,p_verified);
  end if;
end;
$$;
revoke all on function public.admin_set_verification(uuid,boolean) from public;
grant execute on function public.admin_set_verification(uuid,boolean) to authenticated;

-- Public badge lookup exposes only the verification boolean and role for supplied IDs.
create or replace function public.get_public_verification(p_user_ids uuid[])
returns table (id uuid, role text, is_verified boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.role, p.is_verified
  from public.profiles p
  where p.id = any(coalesce(p_user_ids, array[]::uuid[]))
    and p.role in ('buyer','seller')
    and p.is_verified = true;
$$;
revoke all on function public.get_public_verification(uuid[]) from public;
grant execute on function public.get_public_verification(uuid[]) to anon, authenticated;
