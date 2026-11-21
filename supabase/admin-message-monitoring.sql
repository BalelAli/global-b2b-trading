-- Global B2B Trading: admin-only read access for marketplace message monitoring.
-- Run this migration in Supabase SQL Editor after the base dashboard/security migrations.
-- Safe to re-run. Read-only RPCs; no participant message permissions are changed.

create or replace function public.admin_list_message_conversations()
returns table (
  conversation_type text,
  record_id uuid,
  conversation_title text,
  buyer_id uuid,
  buyer_name text,
  buyer_company text,
  buyer_email text,
  seller_id uuid,
  seller_name text,
  seller_company text,
  seller_email text,
  message_count bigint,
  latest_message text,
  latest_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to monitor marketplace messages';
  end if;

  return query
  with rfq_stats as (
    select rm.rfq_id, count(*)::bigint as message_count,
           (array_agg(rm.message order by rm.created_at desc, rm.id desc))[1] as latest_message,
           max(rm.created_at) as latest_at
    from public.rfq_messages rm group by rm.rfq_id
  ), bid_stats as (
    select bm.bid_id, count(*)::bigint as message_count,
           (array_agg(bm.message order by bm.created_at desc, bm.id desc))[1] as latest_message,
           max(bm.created_at) as latest_at
    from public.bid_messages bm group by bm.bid_id
  )
  select 'rfq'::text, r.id, coalesce(prod.name,'RFQ conversation')::text,
         r.buyer_id, coalesce(bp.full_name,'Buyer')::text, coalesce(bp.company_name,'')::text, coalesce(bu.email,'')::text,
         prod.seller_id, coalesce(sp.full_name,'Seller')::text, coalesce(sp.company_name,'')::text, coalesce(su.email,'')::text,
         rs.message_count, rs.latest_message, rs.latest_at
  from rfq_stats rs
  join public.rfqs r on r.id=rs.rfq_id
  join public.products prod on prod.id=r.product_id
  left join public.profiles bp on bp.id=r.buyer_id
  left join public.profiles sp on sp.id=prod.seller_id
  left join auth.users bu on bu.id=r.buyer_id
  left join auth.users su on su.id=prod.seller_id

  union all

  select 'bid'::text, b.id, coalesce(br.title,'Buyer requirement bid conversation')::text,
         br.buyer_id, coalesce(bp.full_name,'Buyer')::text, coalesce(bp.company_name,'')::text, coalesce(bu.email,'')::text,
         b.seller_id, coalesce(sp.full_name,'Seller')::text, coalesce(sp.company_name,'')::text, coalesce(su.email,'')::text,
         bs.message_count, bs.latest_message, bs.latest_at
  from bid_stats bs
  join public.requirement_bids b on b.id=bs.bid_id
  join public.buyer_requirements br on br.id=b.requirement_id
  left join public.profiles bp on bp.id=br.buyer_id
  left join public.profiles sp on sp.id=b.seller_id
  left join auth.users bu on bu.id=br.buyer_id
  left join auth.users su on su.id=b.seller_id
  order by latest_at desc;
end;
$$;

create or replace function public.admin_get_message_history(
  p_conversation_type text,
  p_record_id uuid
)
returns table (
  message_id uuid,
  sender_id uuid,
  sender_name text,
  sender_company text,
  sender_email text,
  message text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com' then
    raise exception 'Not authorized to review marketplace messages';
  end if;

  if p_conversation_type = 'rfq' then
    return query
      select rm.id, rm.sender_id, coalesce(p.full_name,'Marketplace user')::text,
             coalesce(p.company_name,'')::text, coalesce(u.email,'')::text,
             rm.message, rm.created_at
      from public.rfq_messages rm
      left join public.profiles p on p.id=rm.sender_id
      left join auth.users u on u.id=rm.sender_id
      where rm.rfq_id=p_record_id
      order by rm.created_at, rm.id;
  elsif p_conversation_type = 'bid' then
    return query
      select bm.id, bm.sender_id, coalesce(p.full_name,'Marketplace user')::text,
             coalesce(p.company_name,'')::text, coalesce(u.email,'')::text,
             bm.message, bm.created_at
      from public.bid_messages bm
      left join public.profiles p on p.id=bm.sender_id
      left join auth.users u on u.id=bm.sender_id
      where bm.bid_id=p_record_id
      order by bm.created_at, bm.id;
  else
    raise exception 'Invalid conversation type';
  end if;
end;
$$;

revoke all on function public.admin_list_message_conversations() from public, anon;
revoke all on function public.admin_get_message_history(text, uuid) from public, anon;
grant execute on function public.admin_list_message_conversations() to authenticated;
grant execute on function public.admin_get_message_history(text, uuid) to authenticated;
