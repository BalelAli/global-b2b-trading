-- Global B2B Trading: prevent participants from rewriting ownership of existing records.
-- Run once in Supabase SQL Editor after dashboard.sql and the buyer-privacy protections.
-- Safe to re-run. This does not delete or alter existing marketplace records.
--
-- RLS decides WHICH RFQ/bid a seller may update. These triggers additionally ensure
-- the seller cannot change WHO owns that RFQ/bid or rewrite the buyer's original request.

create or replace function public.prevent_marketplace_identity_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'rfqs' then
    if new.buyer_id is distinct from old.buyer_id
       or new.product_id is distinct from old.product_id
       or new.quantity is distinct from old.quantity
       or new.target_price is distinct from old.target_price
       or new.message is distinct from old.message
       or new.created_at is distinct from old.created_at then
      raise exception 'RFQ ownership and original buyer request details cannot be changed';
    end if;
  elsif tg_table_name = 'requirement_bids' then
    if new.seller_id is distinct from old.seller_id
       or new.requirement_id is distinct from old.requirement_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Bid ownership and requirement cannot be changed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_rfq_identity on public.rfqs;
create trigger protect_rfq_identity
before update on public.rfqs
for each row execute function public.prevent_marketplace_identity_changes();

drop trigger if exists protect_requirement_bid_identity on public.requirement_bids;
create trigger protect_requirement_bid_identity
before update on public.requirement_bids
for each row execute function public.prevent_marketplace_identity_changes();

revoke all on function public.prevent_marketplace_identity_changes() from public;
