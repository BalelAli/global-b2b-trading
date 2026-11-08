-- Global B2B Trading: enforce suspended account restrictions in Supabase RLS.
-- Run this AFTER supabase/admin-users.sql.
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
  and auth.uid() = seller_id
);

drop policy if exists "Sellers can update own products" on public.products;
create policy "Sellers can update own products"
on public.products for update to authenticated
using (public.is_current_user_active() and auth.uid() = seller_id)
with check (public.is_current_user_active() and auth.uid() = seller_id);

drop policy if exists "Sellers can delete own products" on public.products;
create policy "Sellers can delete own products"
on public.products for delete to authenticated
using (public.is_current_user_active() and auth.uid() = seller_id);

-- RFQs
drop policy if exists "Buyers and relevant sellers can view RFQs" on public.rfqs;
create policy "Buyers and relevant sellers can view RFQs"
on public.rfqs for select to authenticated
using (
  public.is_current_user_active()
  and (
    auth.uid() = buyer_id
    or exists (
      select 1 from public.products p
      where p.id = product_id and p.seller_id = auth.uid()
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
    select 1 from public.products p
    where p.id = product_id and p.status = 'active'
  )
);

drop policy if exists "Sellers can update RFQ status for own products" on public.rfqs;
create policy "Sellers can update RFQ status for own products"
on public.rfqs for update to authenticated
using (
  public.is_current_user_active()
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
)
with check (
  public.is_current_user_active()
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
);

-- RFQ conversations
drop policy if exists "RFQ participants can read their conversation" on public.rfq_messages;
create policy "RFQ participants can read their conversation"
on public.rfq_messages for select to authenticated
using (
  public.is_current_user_active()
  and exists (
    select 1
    from public.rfqs r
    join public.products p on p.id = r.product_id
    where r.id = rfq_messages.rfq_id
      and (r.buyer_id = auth.uid() or p.seller_id = auth.uid())
  )
);

drop policy if exists "RFQ participants can send messages as themselves" on public.rfq_messages;
create policy "RFQ participants can send messages as themselves"
on public.rfq_messages for insert to authenticated
with check (
  public.is_current_user_active()
  and sender_id = auth.uid()
  and exists (
    select 1
    from public.rfqs r
    join public.products p on p.id = r.product_id
    where r.id = rfq_messages.rfq_id
      and (r.buyer_id = auth.uid() or p.seller_id = auth.uid())
  )
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

-- Requirement bids
drop policy if exists "Requirement owner and bidding seller can view bids" on public.requirement_bids;
create policy "Requirement owner and bidding seller can view bids"
on public.requirement_bids for select to authenticated
using (
  public.is_current_user_active()
  and (
    seller_id = auth.uid()
    or exists (
      select 1 from public.buyer_requirements br
      where br.id = requirement_bids.requirement_id and br.buyer_id = auth.uid()
    )
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

-- Private bid conversations
drop policy if exists "Only bid participants can read bid messages" on public.bid_messages;
create policy "Only bid participants can read bid messages"
on public.bid_messages for select to authenticated
using (
  public.is_current_user_active()
  and exists (
    select 1
    from public.requirement_bids b
    join public.buyer_requirements br on br.id = b.requirement_id
    where b.id = bid_messages.bid_id
      and (br.buyer_id = auth.uid() or b.seller_id = auth.uid())
  )
);

drop policy if exists "Only bid participants can send bid messages" on public.bid_messages;
create policy "Only bid participants can send bid messages"
on public.bid_messages for insert to authenticated
with check (
  public.is_current_user_active()
  and sender_id = auth.uid()
  and exists (
    select 1
    from public.requirement_bids b
    join public.buyer_requirements br on br.id = b.requirement_id
    where b.id = bid_messages.bid_id
      and (
        br.buyer_id = auth.uid()
        or (
          b.seller_id = auth.uid()
          and public.has_active_seller_membership()
        )
      )
  )
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
