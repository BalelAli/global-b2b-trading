-- Repair administrator approval for seller membership requests.
-- Run once in Supabase SQL Editor while signed in as the project owner.

create or replace function public.admin_review_seller_membership(
  p_membership_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_status text;
  v_updated integer;
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to review memberships';
  end if;

  select sm.plan, sm.status
    into v_plan, v_status
  from public.seller_memberships sm
  where sm.id = p_membership_id
  for update;

  if not found then
    raise exception 'Membership request not found';
  end if;

  if v_status <> 'pending' then
    raise exception 'This membership is no longer pending (current status: %)', v_status;
  end if;

  if p_approve then
    update public.seller_memberships
       set status = 'active',
           starts_at = now(),
           expires_at = now() + case
             when v_plan = 'monthly' then interval '1 month'
             when v_plan = 'yearly' then interval '1 year'
             else interval '0'
           end
     where id = p_membership_id
       and status = 'pending';
  else
    update public.seller_memberships
       set status = 'rejected',
           starts_at = null,
           expires_at = null
     where id = p_membership_id
       and status = 'pending';
  end if;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Membership status was not updated. Please refresh and try again.';
  end if;
end;
$$;

revoke all on function public.admin_review_seller_membership(uuid, boolean) from public;
grant execute on function public.admin_review_seller_membership(uuid, boolean) to authenticated;
