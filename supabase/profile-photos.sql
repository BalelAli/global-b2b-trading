-- Global B2B Trading: secure buyer/seller profile picture uploads.
-- Run this once in the Supabase SQL Editor. Safe to re-run.

alter table public.profiles
  add column if not exists avatar_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  true,
  2097152,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Users can view their own profile photo objects" on storage.objects;
create policy "Users can view their own profile photo objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can upload their own profile photo" on storage.objects;
create policy "Users can upload their own profile photo"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and name = auth.uid()::text || '/avatar'
);

drop policy if exists "Users can update their own profile photo" on storage.objects;
create policy "Users can update their own profile photo"
on storage.objects for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and name = auth.uid()::text || '/avatar'
)
with check (
  bucket_id = 'profile-photos'
  and name = auth.uid()::text || '/avatar'
);

drop policy if exists "Users can delete their own profile photo" on storage.objects;
create policy "Users can delete their own profile photo"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and name = auth.uid()::text || '/avatar'
);

create or replace function public.set_my_profile_avatar(p_avatar_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_avatar_path <> auth.uid()::text || '/avatar' then
    raise exception 'Invalid profile photo path';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('buyer', 'seller')
      and coalesce(p.account_status, 'active') = 'active'
  ) then
    raise exception 'Only active buyer and seller accounts can update a profile photo';
  end if;

  update public.profiles
  set avatar_path = p_avatar_path
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

revoke all on function public.set_my_profile_avatar(text) from public;
grant execute on function public.set_my_profile_avatar(text) to authenticated;
