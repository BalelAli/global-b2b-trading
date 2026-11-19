-- Global B2B Trading: repair buyer requirement bid permissions.
-- Run this once in Supabase SQL Editor. Safe to re-run.
-- SECURITY DEFINER helpers avoid direct buyer_requirements table permission errors
-- while returning only a boolean authorization result.

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

drop policy if exists "Only bid participants can read bid messages" on public.bid_messages;
create policy "Only bid participants can read bid messages"
on public.bid_messages for select to authenticated
using (public.can_access_bid_conversation(bid_id));

drop policy if exists "Only bid participants can send bid messages" on public.bid_messages;
create policy "Only bid participants can send bid messages"
on public.bid_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.can_access_bid_conversation(bid_id)
);
