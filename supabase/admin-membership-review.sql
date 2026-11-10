-- Admin-only membership history reader for Global B2B Trading.
-- Run this file once in Supabase SQL Editor.
create or replace function public.admin_list_seller_memberships()
returns table (
  id uuid,
  seller_id uuid,
  plan text,
  amount numeric,
  currency text,
  payment_method text,
  payment_reference text,
  status text,
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view seller membership payments';
  end if;

  return query
  select
    sm.id,
    sm.seller_id,
    sm.plan::text,
    sm.amount::numeric,
    sm.currency::text,
    sm.payment_method::text,
    sm.payment_reference::text,
    sm.status::text,
    sm.starts_at,
    sm.expires_at,
    sm.created_at
  from public.seller_memberships sm
  order by sm.created_at desc;
end;
$$;

revoke all on function public.admin_list_seller_memberships() from public;
grant execute on function public.admin_list_seller_memberships() to authenticated;
