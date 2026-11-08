-- Global B2B Trading: allow the trusted administrator to review all seller products.
-- Read-only policy. Seller product ownership and existing product permissions remain unchanged.
-- Safe to re-run.

drop policy if exists "Admin can view all seller products" on public.products;
create policy "Admin can view all seller products"
on public.products
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
);


-- Securely allow the trusted administrator to activate or deactivate a seller listing.
create or replace function public.admin_set_product_status(
  p_product_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to manage seller products';
  end if;

  if p_status not in ('active', 'inactive') then
    raise exception 'Invalid product status';
  end if;

  update public.products
  set status = p_status
  where id = p_product_id;

  if not found then
    raise exception 'Seller product not found';
  end if;
end;
$$;

revoke all on function public.admin_set_product_status(uuid, text) from public;
grant execute on function public.admin_set_product_status(uuid, text) to authenticated;
