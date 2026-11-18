-- Global B2B Trading: require active seller membership to read or send private bid messages.
-- Apply in Supabase SQL Editor after enforce-account-suspension.sql.
-- Additive policy correction; does not modify or delete marketplace records.

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
      and (
        (
          br.buyer_id = auth.uid()
          and exists (
            select 1 from public.profiles buyer_profile
            where buyer_profile.id = auth.uid()
              and buyer_profile.role = 'buyer'
          )
        )
        or (
          b.seller_id = auth.uid()
          and public.is_current_user_seller()
          and public.has_active_seller_membership()
        )
      )
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
        (
          br.buyer_id = auth.uid()
          and exists (
            select 1 from public.profiles buyer_profile
            where buyer_profile.id = auth.uid()
              and buyer_profile.role = 'buyer'
          )
        )
        or (
          b.seller_id = auth.uid()
          and public.is_current_user_seller()
          and public.has_active_seller_membership()
        )
      )
  )
);
