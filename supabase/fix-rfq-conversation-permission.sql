-- Global B2B Trading: repair RFQ private conversation permission error.
-- Safe to re-run. Does not grant table-level SELECT on rfqs or expose buyer IDs.

create or replace function public.can_access_rfq_conversation(p_rfq_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.can_access_rfq_conversation(uuid) from public;
grant execute on function public.can_access_rfq_conversation(uuid) to authenticated;

drop policy if exists "RFQ participants can read their conversation" on public.rfq_messages;
create policy "RFQ participants can read their conversation"
on public.rfq_messages for select to authenticated
using (public.can_access_rfq_conversation(rfq_id));

drop policy if exists "RFQ participants can send messages as themselves" on public.rfq_messages;
create policy "RFQ participants can send messages as themselves"
on public.rfq_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.can_access_rfq_conversation(rfq_id)
);
