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
