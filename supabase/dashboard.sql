-- Global B2B Trading: buyer/seller dashboard tables
-- Run this script once in Supabase SQL Editor after the original schema.sql.
-- Safe to re-run: policies are dropped before they are recreated.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 160),
  category text not null,
  description text not null default '',
  min_order_qty integer not null default 1 check (min_order_qty > 0),
  price numeric(12,2),
  currency text not null default 'USD',
  country text not null,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now()
);

create index if not exists products_seller_id_idx on public.products(seller_id);
create index if not exists products_status_created_idx on public.products(status, created_at desc);

alter table public.products enable row level security;

drop policy if exists "Public can view active products and sellers can view own" on public.products;
create policy "Public can view active products and sellers can view own"
on public.products for select
using (status = 'active' or auth.uid() = seller_id);

drop policy if exists "Sellers can add own products" on public.products;
create policy "Sellers can add own products"
on public.products for insert to authenticated
with check (auth.uid() = seller_id);

drop policy if exists "Sellers can update own products" on public.products;
create policy "Sellers can update own products"
on public.products for update to authenticated
using (auth.uid() = seller_id)
with check (auth.uid() = seller_id);

drop policy if exists "Sellers can delete own products" on public.products;
create policy "Sellers can delete own products"
on public.products for delete to authenticated
using (auth.uid() = seller_id);

create table if not exists public.rfqs (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  target_price numeric(12,2),
  message text not null default '',
  status text not null default 'new' check (status in ('new','replied','closed')),
  created_at timestamptz not null default now()
);

-- Dashboard reply fields used by seller and buyer views (also upgrades existing tables).
alter table public.rfqs add column if not exists seller_reply text;
alter table public.rfqs add column if not exists seller_replied_at timestamptz;

create index if not exists rfqs_buyer_id_idx on public.rfqs(buyer_id);
create index if not exists rfqs_product_id_idx on public.rfqs(product_id);

alter table public.rfqs enable row level security;

drop policy if exists "Buyers and relevant sellers can view RFQs" on public.rfqs;
create policy "Buyers and relevant sellers can view RFQs"
on public.rfqs for select to authenticated
using (
  auth.uid() = buyer_id
  or exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
);

drop policy if exists "Buyers can send RFQs for active products" on public.rfqs;
create policy "Buyers can send RFQs for active products"
on public.rfqs for insert to authenticated
with check (
  auth.uid() = buyer_id
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.status = 'active'
  )
);

drop policy if exists "Sellers can update RFQ status for own products" on public.rfqs;
create policy "Sellers can update RFQ status for own products"
on public.rfqs for update to authenticated
using (
  exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
);

-- Only buyers may create RFQs; sellers cannot change the buyer_id or product_id
-- through the dashboard UI. Row-level security still validates ownership.

-- Private one-to-one conversation messages for each RFQ.
-- Only the buyer who created the RFQ and the seller who owns its product
-- can read or send messages in that RFQ conversation.
create table if not exists public.rfq_messages (
  id uuid primary key default gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message text not null check (char_length(trim(message)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists rfq_messages_rfq_created_idx
on public.rfq_messages(rfq_id, created_at);

alter table public.rfq_messages enable row level security;

grant select, insert on public.rfq_messages to authenticated;

drop policy if exists "RFQ participants can read their conversation" on public.rfq_messages;
create policy "RFQ participants can read their conversation"
on public.rfq_messages for select to authenticated
using (
  exists (
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
  sender_id = auth.uid()
  and exists (
    select 1
    from public.rfqs r
    join public.products p on p.id = r.product_id
    where r.id = rfq_messages.rfq_id
      and (r.buyer_id = auth.uid() or p.seller_id = auth.uid())
  )
);
