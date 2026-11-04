-- Global B2B Trading: initial account profile schema
-- Run this once in the Supabase SQL Editor for your project.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('buyer', 'seller')),
  full_name text not null,
  company_name text not null,
  country text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Each signed-in user can read only their own profile.
create policy "Read own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

-- Profile creation is performed by the trusted auth trigger below.
-- No public insert policy is needed.

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, role, full_name, company_name, country)
  values (
    new.id,
    case when new.raw_user_meta_data ->> 'role' = 'seller' then 'seller' else 'buyer' end,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'company_name', ''),
    coalesce(new.raw_user_meta_data ->> 'country', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();
