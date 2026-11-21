-- Global B2B Trading: harden seller membership payment access and review.
-- Additive security migration. Preserves membership records and seller self-service.
-- Requires public.is_trusted_marketplace_admin() from admin-role-hardening.sql.
-- Safe to re-run.

begin;

-- Replace the legacy email-only policy. Admin access requires BOTH the trusted
-- administrator email and an admin role in profiles.
drop policy if exists "Admin can view all seller membership requests" on public.seller_memberships;
create policy "Admin can view all seller membership requests"
on public.seller_memberships
for select
to authenticated
using (public.is_trusted_marketplace_admin());

-- Keep the admin review action behind the same trusted authorization check.
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
begin
  if not public.is_trusted_marketplace_admin() then
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
    raise exception 'Only pending membership requests can be reviewed';
  end if;

  if p_approve then
    update public.seller_memberships
    set status = 'active',
        starts_at = now(),
        expires_at = now() + case
          when v_plan = 'monthly' then interval '1 month'
          else interval '1 year'
        end
    where id = p_membership_id;
  else
    update public.seller_memberships
    set status = 'rejected',
        starts_at = null,
        expires_at = null
    where id = p_membership_id;
  end if;
end;
$$;

revoke all on function public.admin_review_seller_membership(uuid, boolean) from public, anon;
grant execute on function public.admin_review_seller_membership(uuid, boolean) to authenticated;

-- Membership history RPC remains admin-only, with the same trusted check.
create or replace function public.admin_list_seller_memberships()
returns table (
  id uuid,
  seller_id uuid,
  plan text,
  amount numeric,
  currency text,
  payment_method text,
  payment_reference text,
  status text,
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_trusted_marketplace_admin() then
    raise exception 'Not authorized to view seller membership payments';
  end if;

  return query
  select sm.id, sm.seller_id, sm.plan::text, sm.amount::numeric,
         sm.currency::text, sm.payment_method::text,
         sm.payment_reference::text, sm.status::text,
         sm.starts_at, sm.expires_at, sm.created_at
  from public.seller_memberships sm
  order by sm.created_at desc;
end;
$$;

revoke all on function public.admin_list_seller_memberships() from public, anon;
grant execute on function public.admin_list_seller_memberships() to authenticated;

commit;
