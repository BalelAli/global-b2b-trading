-- Global B2B Trading: secure admin access to buyer requirements
-- Run this once in Supabase SQL Editor. Safe to re-run.

drop policy if exists "Admin can view all buyer requirements" on public.buyer_requirements;
create policy "Admin can view all buyer requirements"
on public.buyer_requirements
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
);

create or replace function public.admin_set_requirement_status(
  p_requirement_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to manage buyer requirements';
  end if;

  if p_status not in ('open', 'closed') then
    raise exception 'Invalid requirement status';
  end if;

  update public.buyer_requirements
  set status = p_status
  where id = p_requirement_id;

  if not found then
    raise exception 'Buyer requirement not found';
  end if;
end;
$$;

revoke all on function public.admin_set_requirement_status(uuid, text) from public;
grant execute on function public.admin_set_requirement_status(uuid, text) to authenticated;
