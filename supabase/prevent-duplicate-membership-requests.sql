-- Global B2B Trading: enforce one pending membership request per seller.
-- Also prevent a seller from receiving overlapping active memberships.
-- Run after dashboard.sql and enforce-account-suspension.sql.
-- Safe to re-run. Existing membership records are preserved.

create or replace function public.guard_seller_membership_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('pending', 'active') then
    -- Serialize membership submissions and approvals for this seller so two
    -- concurrent requests cannot both pass the same existence check.
    perform 1
      from public.profiles as p
     where p.id = new.seller_id
     for update;

    if not found then
      raise exception 'Seller profile not found for this membership request';
    end if;

    if new.status = 'pending' and exists (
      select 1
        from public.seller_memberships as sm
       where sm.seller_id = new.seller_id
         and sm.id is distinct from new.id
         and (
           sm.status = 'pending'
           or (
             sm.status = 'active'
             and sm.starts_at is not null
             and sm.expires_at is not null
             and sm.starts_at <= now()
             and sm.expires_at > now()
           )
         )
    ) then
      raise exception 'A pending payment or active membership already exists for this seller';
    end if;

    if new.status = 'active'
       and new.starts_at is not null
       and new.expires_at is not null
       and new.starts_at <= now()
       and new.expires_at > now()
       and exists (
         select 1
           from public.seller_memberships as sm
          where sm.seller_id = new.seller_id
            and sm.id is distinct from new.id
            and sm.status = 'active'
            and sm.starts_at is not null
            and sm.expires_at is not null
            and sm.starts_at <= now()
            and sm.expires_at > now()
       ) then
      raise exception 'Another active membership already exists for this seller';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.guard_seller_membership_request() from public, anon, authenticated;

drop trigger if exists guard_seller_membership_request on public.seller_memberships;
create trigger guard_seller_membership_request
before insert or update of seller_id, status, starts_at, expires_at
on public.seller_memberships
for each row
execute function public.guard_seller_membership_request();
