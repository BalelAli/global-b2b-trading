-- Global B2B Trading: harden legacy admin-only policies and RPCs
-- Uses a SECURITY DEFINER helper to avoid recursive profiles RLS in admin profile policies.
-- Safe to re-run. No marketplace data is changed or deleted.

begin;

create or replace function public.is_trusted_marketplace_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    );
$$;
revoke all on function public.is_trusted_marketplace_admin() from public, anon;
grant execute on function public.is_trusted_marketplace_admin() to authenticated;

-- Admin-only read policies. The helper avoids recursive profiles-policy evaluation.
drop policy if exists "Admin can view all seller products" on public.products;
create policy "Admin can view all seller products"
on public.products for select to authenticated
using (public.is_trusted_marketplace_admin());

drop policy if exists "Admin can view all buyer requirements" on public.buyer_requirements;
create policy "Admin can view all buyer requirements"
on public.buyer_requirements for select to authenticated
using (public.is_trusted_marketplace_admin());

drop policy if exists "Admin can view all quotation requests" on public.rfqs;
create policy "Admin can view all quotation requests"
on public.rfqs for select to authenticated
using (public.is_trusted_marketplace_admin());

-- Remove the older admin-users policy that queried profiles from a profiles
-- policy and could trigger recursive RLS evaluation.
drop policy if exists "Admin can view all marketplace users" on public.profiles;

drop policy if exists "Admin can view all seller profiles" on public.profiles;
create policy "Admin can view all seller profiles"
on public.profiles for select to authenticated
using (
  public.is_trusted_marketplace_admin()
  and role = 'seller'
);

drop policy if exists "Admin can read buyer and seller directory" on public.profiles;
create policy "Admin can read buyer and seller directory"
on public.profiles for select to authenticated
using (
  public.is_trusted_marketplace_admin()
  and role in ('buyer', 'seller')
);

-- Admin-only product status RPC.
create or replace function public.admin_set_product_status(p_product_id uuid, p_status text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_trusted_marketplace_admin() then
    raise exception 'Not authorized to manage seller products';
  end if;
  if p_status not in ('active', 'inactive') then
    raise exception 'Invalid product status';
  end if;
  update public.products set status = p_status where id = p_product_id;
  if not found then raise exception 'Seller product not found'; end if;
end;
$$;
revoke all on function public.admin_set_product_status(uuid, text) from public, anon;
grant execute on function public.admin_set_product_status(uuid, text) to authenticated;

-- Admin-only buyer requirement status RPC.
create or replace function public.admin_set_requirement_status(p_requirement_id uuid, p_status text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_trusted_marketplace_admin() then
    raise exception 'Not authorized to manage buyer requirements';
  end if;
  if p_status not in ('open', 'closed') then
    raise exception 'Invalid requirement status';
  end if;
  update public.buyer_requirements set status = p_status where id = p_requirement_id;
  if not found then raise exception 'Buyer requirement not found'; end if;
end;
$$;
revoke all on function public.admin_set_requirement_status(uuid, text) from public, anon;
grant execute on function public.admin_set_requirement_status(uuid, text) to authenticated;

-- Admin-only RFQ export/list RPC.
create or replace function public.admin_list_rfqs()
returns table (
  id uuid, product_id uuid, product_name text, status text, quantity integer,
  target_price numeric, currency text, buyer_id uuid, seller_id uuid,
  message text, seller_reply text, created_at timestamptz, seller_replied_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_trusted_marketplace_admin() then
    raise exception 'Not authorized to view RFQ reports';
  end if;
  return query
    select r.id, r.product_id, p.name, r.status, r.quantity, r.target_price,
           p.currency, r.buyer_id, p.seller_id, r.message, r.seller_reply,
           r.created_at, r.seller_replied_at
    from public.rfqs r
    join public.products p on p.id = r.product_id
    order by r.created_at desc;
end;
$$;
revoke all on function public.admin_list_rfqs() from public, anon;
grant execute on function public.admin_list_rfqs() to authenticated;

-- Admin-only private contact directory RPC.
create or replace function public.admin_list_user_directory()
returns table (
  id uuid, role text, full_name text, company_name text, country text,
  account_status text, created_at timestamptz, email text, phone text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_trusted_marketplace_admin() then
    raise exception 'Not authorized to view marketplace contact details';
  end if;
  return query
    select p.id, p.role, p.full_name, p.company_name, p.country,
           coalesce(p.account_status, 'active')::text, u.created_at,
           coalesce(u.email, '')::text,
           coalesce(nullif(u.phone, ''), u.raw_user_meta_data ->> 'phone', '')::text
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.role in ('buyer', 'seller')
    order by u.created_at desc;
end;
$$;
revoke all on function public.admin_list_user_directory() from public, anon;
grant execute on function public.admin_list_user_directory() to authenticated;

commit;
