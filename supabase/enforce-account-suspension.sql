-- Global B2B Trading: enforce suspended account restrictions in Supabase RLS.
-- Run this AFTER supabase/dashboard.sql, supabase/admin-users.sql, and the privacy/admin policy migrations.
-- This migration only replaces marketplace access policies; it does not edit or delete data.
-- Safe to re-run.

-- Security-definer helper: anonymous visitors remain eligible for public product browsing.
-- Authenticated users must have an active buyer/seller/admin profile.
create or replace function public.is_current_user_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is null
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com'
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.account_status, 'active') = 'active'
        and p.role in ('buyer', 'seller', 'admin')
    );
$$;

revoke all on function public.is_current_user_active() from public;
grant execute on function public.is_current_user_active() to authenticated, anon;

-- Remove any legacy permissive policies for sensitive seller operations first.
-- PostgreSQL combines permissive policies with OR, so replacing only a known policy
-- name can leave an older, more permissive policy active.
do $$
declare
  pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and (
        (tablename = 'products' and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL'))
        or (tablename = 'rfqs' and cmd in ('UPDATE', 'ALL'))
        or (tablename = 'rfq_messages' and cmd in ('SELECT', 'INSERT', 'ALL'))
        or (tablename = 'bid_messages' and cmd in ('SELECT', 'INSERT', 'ALL'))
      )
  loop
    execute format('drop policy %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  end loop;
end;
$$;

-- Products
drop policy if exists "Public can view active products and sellers can view own" on public.products;
create policy "Public can view active products and sellers can view own"
on public.products for select
using (
  public.is_current_user_active()
  and (status = 'active' or auth.uid() = seller_id)
);

drop policy if exists "Sellers can add own products" on public.products;
create policy "Sellers can add own products"
on public.products for insert to authenticated
with check (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and auth.uid() = seller_id
);

drop policy if exists "Sellers can update own products" on public.products;
create policy "Sellers can update own products"
on public.products for update to authenticated
using (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and auth.uid() = seller_id
)
with check (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and auth.uid() = seller_id
);

drop policy if exists "Sellers can delete own products" on public.products;
create policy "Sellers can delete own products"
on public.products for delete to authenticated
using (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and auth.uid() = seller_id
);

-- RFQs
drop policy if exists "Buyers and relevant sellers can view RFQs" on public.rfqs;
create policy "Buyers and relevant sellers can view RFQs"
on public.rfqs for select to authenticated
using (
  public.is_current_user_active()
  and (
    (
      auth.uid() = buyer_id
      and exists (
        select 1 from public.profiles buyer_profile
        where buyer_profile.id = auth.uid()
          and buyer_profile.role = 'buyer'
      )
    )
    or (
      public.is_current_user_seller()
      and public.has_active_seller_membership()
      and exists (
        select 1 from public.products p
        where p.id = product_id and p.seller_id = auth.uid()
      )
    )
  )
);

drop policy if exists "Buyers can send RFQs for active products" on public.rfqs;
create policy "Buyers can send RFQs for active products"
on public.rfqs for insert to authenticated
with check (
  public.is_current_user_active()
  and auth.uid() = buyer_id
  and exists (
    select 1 from public.profiles buyer_profile
    where buyer_profile.id = auth.uid()
      and buyer_profile.role = 'buyer'
  )
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.status = 'active'
  )
);

drop policy if exists "Sellers can update RFQ status for own products" on public.rfqs;
create policy "Sellers can update RFQ status for own products"
on public.rfqs for update to authenticated
using (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and public.has_active_seller_membership()
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
)
with check (
  public.is_current_user_active()
  and public.is_current_user_seller()
  and public.has_active_seller_membership()
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
);

-- RFQ conversations. Use a narrowly scoped SECURITY DEFINER helper to check
-- participation because buyer privacy migration revokes table-level SELECT
-- from rfqs and hides buyer_id via column grants. The helper returns only a
-- boolean and does not expose RFQ details.
create or replace function public.can_access_rfq_conversation(p_rfq_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $
  select
    public.is_current_user_active()
    and exists (
      select 1
      from public.rfqs r
      join public.products p on p.id = r.product_id
      where r.id = p_rfq_id
        and (
          (
            r.buyer_id = auth.uid()
            and exists (
              select 1 from public.profiles bp
              where bp.id = auth.uid() and bp.role = 'buyer'
            )
          )
          or (
            p.seller_id = auth.uid()
            and public.is_current_user_seller()
            and public.has_active_seller_membership()
          )
        )
    );
$;
revoke all on function public.can_access_rfq_conversation(uuid) from public;
grant execute on function public.can_access_rfq_conversation(uuid) to authenticated;

drop policy if exists "RFQ participants can read their conversation" on public.rfq_messages;
create policy "RFQ participants can read their conversation"
on public.rfq_messages for select to authenticated
using (
  public.can_access_rfq_conversation(rfq_id)
);

drop policy if exists "RFQ participants can send messages as themselves" on public.rfq_messages;
create policy "RFQ participants can send messages as themselves"
on public.rfq_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.can_access_rfq_conversation(rfq_id)
);

-- Buyer requirements. The separate admin SELECT policy remains in place.
drop policy if exists "Buyer owners and all sellers can view open requirements" on public.buyer_requirements;
create policy "Buyer owners and all sellers can view open requirements"
on public.buyer_requirements for select to authenticated
using (
  public.is_current_user_active()
  and (
    buyer_id = auth.uid()
    or (status = 'open' and public.is_current_user_seller())
  )
);

drop policy if exists "Buyers can publish own requirements" on public.buyer_requirements;
create policy "Buyers can publish own requirements"
on public.buyer_requirements for insert to authenticated
with check (
  public.is_current_user_active()
  and buyer_id = auth.uid()
  and not public.is_current_user_seller()
);

drop policy if exists "Buyers can update own requirements" on public.buyer_requirements;
create policy "Buyers can update own requirements"
on public.buyer_requirements for update to authenticated
using (
  public.is_current_user_active()
  and buyer_id = auth.uid()
  and not public.is_current_user_seller()
)
with check (
  public.is_current_user_active()
  and buyer_id = auth.uid()
  and not public.is_current_user_seller()
);

-- Buyer privacy compatibility: bid policies must not query the restricted buyer_id
-- column from buyer_requirements under the caller's privileges. These helpers
-- return only an authorization boolean and are owned by the migration executor.
create or replace function public.is_owner_of_requirement(p_requirement_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_current_user_active()
    and exists (
      select 1
      from public.buyer_requirements br
      where br.id = p_requirement_id
        and br.buyer_id = auth.uid()
        and exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role = 'buyer'
        )
    );
$$;

revoke all on function public.is_owner_of_requirement(uuid) from public;
grant execute on function public.is_owner_of_requirement(uuid) to authenticated;

create or replace function public.can_access_bid_conversation(p_bid_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_current_user_active()
    and exists (
      select 1
      from public.requirement_bids b
      join public.buyer_requirements br on br.id = b.requirement_id
      where b.id = p_bid_id
        and (
          public.is_owner_of_requirement(br.id)
          or (
            b.seller_id = auth.uid()
            and public.is_current_user_seller()
            and public.has_active_seller_membership()
          )
        )
    );
$$;

revoke all on function public.can_access_bid_conversation(uuid) from public;
grant execute on function public.can_access_bid_conversation(uuid) to authenticated;

-- Requirement bids
drop policy if exists "Requirement owner and bidding seller can view bids" on public.requirement_bids;
create policy "Requirement owner and bidding seller can view bids"
on public.requirement_bids for select to authenticated
using (
  public.is_current_user_active()
  and (
    seller_id = auth.uid()
    or public.is_owner_of_requirement(requirement_id)
  )
);

drop policy if exists "Sellers can bid on open requirements" on public.requirement_bids;
create policy "Sellers can bid on open requirements"
on public.requirement_bids for insert to authenticated
with check (
  public.is_current_user_active()
  and seller_id = auth.uid()
  and public.is_current_user_seller()
  and public.has_active_seller_membership()
  and exists (
    select 1 from public.buyer_requirements br
    where br.id = requirement_bids.requirement_id and br.status = 'open'
  )
);

drop policy if exists "Sellers can update their own bids" on public.requirement_bids;
create policy "Sellers can update their own bids"
on public.requirement_bids for update to authenticated
using (
  public.is_current_user_active()
  and seller_id = auth.uid()
  and public.is_current_user_seller()
  and public.has_active_seller_membership()
)
with check (
  public.is_current_user_active()
  and seller_id = auth.uid()
  and public.is_current_user_seller()
  and public.has_active_seller_membership()
);

-- Private bid conversations. Sellers must keep an active membership to read
-- or send bid messages; buyers can always access their own requirement conversations.
drop policy if exists "Only bid participants can read bid messages" on public.bid_messages;
create policy "Only bid participants can read bid messages"
on public.bid_messages for select to authenticated
using (public.can_access_bid_conversation(bid_id));

drop policy if exists "Only bid participants can send bid messages" on public.bid_messages;
create policy "Only bid participants can send bid messages"
on public.bid_messages for insert to authenticated
with check (
  public.is_current_user_active()
  and sender_id = auth.uid()
  and public.can_access_bid_conversation(bid_id)
);

-- Seller membership records. The separate admin SELECT policy remains in place.
drop policy if exists "Sellers can view their own membership records" on public.seller_memberships;
create policy "Sellers can view their own membership records"
on public.seller_memberships for select to authenticated
using (public.is_current_user_active() and seller_id = auth.uid());

drop policy if exists "Sellers can submit their own membership payment" on public.seller_memberships;
create policy "Sellers can submit their own membership payment"
on public.seller_memberships for insert to authenticated
with check (
  public.is_current_user_active()
  and seller_id = auth.uid()
  and public.is_current_user_seller()
  and status = 'pending'
  and starts_at is null
  and expires_at is null
  and (
    (plan = 'monthly' and amount = 10.00)
    or (plan = 'yearly' and amount = 100.00)
  )
);

-- Note: own-profile SELECT is intentionally left available so the dashboard can
-- detect suspension and show the support message before signing the user out.
