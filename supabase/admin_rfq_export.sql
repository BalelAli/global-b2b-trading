-- Global B2B Trading: admin RFQ export support
-- Apply this migration in Supabase SQL Editor as the project owner.
-- Admin access is restricted to the verified Auth email configured below.

begin;

-- The Admin dashboard reads only basic buyer/seller profile fields.
-- Regular users remain restricted to their own profile.
drop policy if exists "Admin can read buyer and seller directory" on public.profiles;
create policy "Admin can read buyer and seller directory"
on public.profiles
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
);

-- Remove the earlier function signature/return type before defining the dashboard-compatible result.
-- This function is called by the Admin dashboard; no database objects should depend on it.
drop function if exists public.admin_list_rfqs();

-- Return the RFQ fields consumed by dashboard.html's Admin RFQ list and CSV export.
-- Seller identity is derived from the product owner; it is not accepted from the caller.
create or replace function public.admin_list_rfqs()
returns table (
  id uuid,
  product_id uuid,
  product_name text,
  status text,
  quantity integer,
  target_price numeric,
  currency text,
  buyer_id uuid,
  seller_id uuid,
  message text,
  seller_reply text,
  created_at timestamptz,
  seller_replied_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view RFQ reports';
  end if;

  return query
  select
    r.id,
    r.product_id,
    p.name,
    r.status,
    r.quantity,
    r.target_price,
    p.currency,
    r.buyer_id,
    p.seller_id,
    r.message,
    r.seller_reply,
    r.created_at,
    r.seller_replied_at
  from public.rfqs r
  join public.products p on p.id = r.product_id
  order by r.created_at desc;
end;
$$;

revoke all on function public.admin_list_rfqs() from public;
grant execute on function public.admin_list_rfqs() to authenticated;

commit;
