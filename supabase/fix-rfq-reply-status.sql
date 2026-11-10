-- Global B2B Trading: repair RFQ status for requests that already have a seller reply.
-- This only changes inconsistent rows: status='new' with a non-empty seller_reply.
-- It does not change RFQ messages, prices, quantities, or ownership.

begin;

update public.rfqs
set status = 'replied'
where status = 'new'
  and nullif(btrim(seller_reply), '') is not null;

commit;
