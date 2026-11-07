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


-- Open buyer requirements: visible to the requirement owner and all signed-in sellers.
-- Bids are private: only the requirement owner and the bidding seller can read them.
create or replace function public.is_current_user_seller()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'seller'
  );
$$;

revoke all on function public.is_current_user_seller() from public;
grant execute on function public.is_current_user_seller() to authenticated;

create table if not exists public.buyer_requirements (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 160),
  category text not null default '',
  description text not null default '',
  quantity integer not null check (quantity > 0),
  target_price numeric(12,2),
  currency text not null default 'USD',
  destination_country text not null default '',
  status text not null default 'open' check (status in ('open','closed')),
  created_at timestamptz not null default now()
);

create index if not exists buyer_requirements_status_created_idx
on public.buyer_requirements(status, created_at desc);
create index if not exists buyer_requirements_buyer_idx
on public.buyer_requirements(buyer_id);

alter table public.buyer_requirements enable row level security;
grant select, insert, update on public.buyer_requirements to authenticated;

drop policy if exists "Buyer owners and all sellers can view open requirements" on public.buyer_requirements;
create policy "Buyer owners and all sellers can view open requirements"
on public.buyer_requirements for select to authenticated
using (buyer_id = auth.uid() or (status = 'open' and public.is_current_user_seller()));

drop policy if exists "Buyers can publish own requirements" on public.buyer_requirements;
create policy "Buyers can publish own requirements"
on public.buyer_requirements for insert to authenticated
with check (buyer_id = auth.uid() and not public.is_current_user_seller());

drop policy if exists "Buyers can update own requirements" on public.buyer_requirements;
create policy "Buyers can update own requirements"
on public.buyer_requirements for update to authenticated
using (buyer_id = auth.uid() and not public.is_current_user_seller())
with check (buyer_id = auth.uid() and not public.is_current_user_seller());

create table if not exists public.requirement_bids (
  id uuid primary key default gen_random_uuid(),
  requirement_id uuid not null references public.buyer_requirements(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  price numeric(12,2) not null check (price >= 0),
  currency text not null default 'USD',
  min_order_qty integer,
  lead_time_days integer,
  message text not null default '',
  created_at timestamptz not null default now(),
  unique(requirement_id, seller_id)
);

create index if not exists requirement_bids_requirement_idx
on public.requirement_bids(requirement_id, created_at);

alter table public.requirement_bids enable row level security;
grant select, insert, update on public.requirement_bids to authenticated;

drop policy if exists "Requirement owner and bidding seller can view bids" on public.requirement_bids;
create policy "Requirement owner and bidding seller can view bids"
on public.requirement_bids for select to authenticated
using (
  seller_id = auth.uid()
  or exists (
    select 1 from public.buyer_requirements br
    where br.id = requirement_bids.requirement_id and br.buyer_id = auth.uid()
  )
);

drop policy if exists "Sellers can bid on open requirements" on public.requirement_bids;
create policy "Sellers can bid on open requirements"
on public.requirement_bids for insert to authenticated
with check (
  seller_id = auth.uid()
  and public.is_current_user_seller()
  and exists (
    select 1 from public.buyer_requirements br
    where br.id = requirement_bids.requirement_id and br.status = 'open'
  )
);

drop policy if exists "Sellers can update their own bids" on public.requirement_bids;
create policy "Sellers can update their own bids"
on public.requirement_bids for update to authenticated
using (seller_id = auth.uid() and public.is_current_user_seller())
with check (seller_id = auth.uid() and public.is_current_user_seller());

-- Private messages for one buyer and one seller, scoped to their specific bid.
create table if not exists public.bid_messages (
  id uuid primary key default gen_random_uuid(),
  bid_id uuid not null references public.requirement_bids(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message text not null check (char_length(trim(message)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists bid_messages_bid_created_idx
on public.bid_messages(bid_id, created_at);

alter table public.bid_messages enable row level security;
grant select, insert on public.bid_messages to authenticated;

drop policy if exists "Only bid participants can read bid messages" on public.bid_messages;
create policy "Only bid participants can read bid messages"
on public.bid_messages for select to authenticated
using (
  exists (
    select 1
    from public.requirement_bids b
    join public.buyer_requirements br on br.id = b.requirement_id
    where b.id = bid_messages.bid_id
      and (br.buyer_id = auth.uid() or b.seller_id = auth.uid())
  )
);

drop policy if exists "Only bid participants can send messages as themselves" on public.bid_messages;
create policy "Only bid participants can send messages as themselves"
on public.bid_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.requirement_bids b
    join public.buyer_requirements br on br.id = b.requirement_id
    where b.id = bid_messages.bid_id
      and (br.buyer_id = auth.uid() or b.seller_id = auth.uid())
  )
);


-- Seller membership subscriptions. Sellers submit payment references;
-- only a trusted administrator should activate membership status.
create table if not exists public.seller_memberships (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  plan text not null check (plan in ('monthly','yearly')),
  amount numeric(10,2) not null check (amount > 0),
  currency text not null default 'USD' check (currency = 'USD'),
  payment_method text not null check (payment_method in ('bKash','Nagad','PayPal','Bank Transfer')),
  payment_reference text not null check (char_length(trim(payment_reference)) between 3 and 160),
  status text not null default 'pending' check (status in ('pending','active','rejected','expired')),
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists seller_memberships_seller_created_idx
on public.seller_memberships(seller_id, created_at desc);

alter table public.seller_memberships enable row level security;
grant select, insert on public.seller_memberships to authenticated;

drop policy if exists "Sellers can view their own membership records" on public.seller_memberships;
create policy "Sellers can view their own membership records"
on public.seller_memberships for select to authenticated
using (seller_id = auth.uid());

drop policy if exists "Sellers can submit their own membership payment" on public.seller_memberships;
create policy "Sellers can submit their own membership payment"
on public.seller_memberships for insert to authenticated
with check (
  seller_id = auth.uid()
  and public.is_current_user_seller()
  and status = 'pending'
  and starts_at is null
  and expires_at is null
  and (
    (plan = 'monthly' and amount = 10.00)
    or (plan = 'yearly' and amount = 100.00)
  )
);

create or replace function public.has_active_seller_membership()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.seller_memberships sm
    where sm.seller_id = auth.uid()
      and sm.status = 'active'
      and sm.starts_at <= now()
      and sm.expires_at > now()
  );
$$;

revoke all on function public.has_active_seller_membership() from public;
grant execute on function public.has_active_seller_membership() to authenticated;

-- Require an active, unexpired membership before a seller can bid or update a bid.
drop policy if exists "Sellers can bid on open requirements" on public.requirement_bids;
create policy "Sellers can bid on open requirements"
on public.requirement_bids for insert to authenticated
with check (
  seller_id = auth.uid()
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
using (seller_id = auth.uid() and public.is_current_user_seller() and public.has_active_seller_membership())
with check (seller_id = auth.uid() and public.is_current_user_seller() and public.has_active_seller_membership());

-- Sellers must also have an active membership to send private bid messages.
drop policy if exists "Only bid participants can send bid messages" on public.bid_messages;
create policy "Only bid participants can send bid messages"
on public.bid_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.requirement_bids b
    join public.buyer_requirements br on br.id = b.requirement_id
    where b.id = bid_messages.bid_id
      and (
        br.buyer_id = auth.uid()
        or (b.seller_id = auth.uid() and public.has_active_seller_membership())
      )
  )
);
