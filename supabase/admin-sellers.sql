-- Global B2B Trading: allow the trusted admin to view seller profiles
-- Safe to re-run. This adds read-only admin visibility; it does not change seller accounts.

drop policy if exists "Admin can view all seller profiles" on public.profiles;
create policy "Admin can view all seller profiles"
on public.profiles
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
);
