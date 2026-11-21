-- Admin-only seller profile visibility.
-- Uses the trusted admin helper from admin-role-hardening.sql.
-- Safe to re-run; does not modify seller records.

drop policy if exists "Admin can view all seller profiles" on public.profiles;
create policy "Admin can view all seller profiles"
on public.profiles
for select
to authenticated
using (public.is_trusted_marketplace_admin());
