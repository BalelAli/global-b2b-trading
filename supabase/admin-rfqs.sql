-- Global B2B Trading: read-only administrator access to all buyer RFQs.
-- Safe to re-run. Does not change RFQ data or participant messaging permissions.

drop policy if exists "Admin can view all quotation requests" on public.rfqs;
create policy "Admin can view all quotation requests"
on public.rfqs
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
);
