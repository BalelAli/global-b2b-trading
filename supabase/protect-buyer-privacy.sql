-- Global B2B Trading: protect buyer identity from seller-facing queries.
-- Run after the dashboard.html update. Safe to re-run; does not delete or edit marketplace records.
--
-- Sellers can continue to see the commercial requirement details needed to quote:
-- product, category, specifications, quantity, target price, currency and destination country.
-- Buyer IDs are excluded from normal authenticated SELECT privileges.
-- Admin-only security-definer RPCs preserve admin reporting.

-- Remove table-level SELECT so column-level grants can hide buyer_id.
revoke select on table public.buyer_requirements from authenticated;
grant select (
  id, title, category, description, quantity, target_price, currency,
  destination_country, status, created_at
) on table public.buyer_requirements to authenticated;

revoke select on table public.rfqs from authenticated;
grant select (
  id, product_id, quantity, target_price, message, status,
  seller_reply, seller_replied_at, created_at
) on table public.rfqs to authenticated;

-- Admin-only list of all buyer requirements, including buyer_id.
create or replace function public.admin_list_requirements()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view all buyer requirements';
  end if;

  return query
    select to_jsonb(br)
    from public.buyer_requirements as br
    order by br.created_at desc;
end;
$$;

revoke all on function public.admin_list_requirements() from public;
grant execute on function public.admin_list_requirements() to authenticated;

-- Admin-only RFQ report. Buyer identity is available only to the trusted admin.
-- The export migration may define this RPC with a typed return table; drop either
-- prior signature first so this migration can be safely applied in either order.
drop function if exists public.admin_list_rfqs();

create or replace function public.admin_list_rfqs()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to view all quotation requests';
  end if;

  return query
    select
      to_jsonb(r) || jsonb_build_object(
        'product_name', p.name,
        'seller_id', p.seller_id,
        'currency', p.currency
      )
    from public.rfqs as r
    left join public.products as p on p.id = r.product_id
    order by r.created_at desc;
end;
$$;

revoke all on function public.admin_list_rfqs() from public;
grant execute on function public.admin_list_rfqs() to authenticated;
