-- Global B2B Trading: private administrator contact directory
-- Admin-only access to registered buyer/seller email and phone.
-- Does not expose contact details to buyers or sellers.

create or replace function public.admin_list_user_directory()
returns table (
  id uuid,
  role text,
  full_name text,
  company_name text,
  country text,
  account_status text,
  created_at timestamptz,
  email text,
  phone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view marketplace contact details';
  end if;

  return query
  select
    p.id,
    p.role,
    p.full_name,
    p.company_name,
    p.country,
    coalesce(p.account_status, 'active')::text,
    u.created_at,
    coalesce(u.email, '')::text,
    coalesce(nullif(u.phone, ''), u.raw_user_meta_data ->> 'phone', '')::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.role in ('buyer', 'seller')
  order by u.created_at desc;
end;
$$;

revoke all on function public.admin_list_user_directory() from public;
grant execute on function public.admin_list_user_directory() to authenticated;
