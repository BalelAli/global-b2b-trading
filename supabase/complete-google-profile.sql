-- Global B2B Trading: safely save the selected role and business details after Google OAuth.
-- Run after schema.sql, dashboard.sql, enable-admin-role.sql and admin-users.sql.
-- Safe to re-run. This does not permit an account to become an administrator.

create or replace function public.complete_my_oauth_profile(
  p_role text,
  p_full_name text,
  p_company_name text,
  p_country text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if lower(coalesce(auth.jwt() ->> 'email', '')) = 'balelali953@gmail.com' then
    raise exception 'The administrator profile cannot be changed through Google role selection';
  end if;

  if p_role is null or p_role not in ('buyer', 'seller') then
    raise exception 'Choose either a buyer or seller account';
  end if;

  if length(trim(coalesce(p_full_name, ''))) not between 1 and 80
     or length(trim(coalesce(p_company_name, ''))) not between 1 and 120
     or length(trim(coalesce(p_country, ''))) not between 1 and 80 then
    raise exception 'Enter a valid name, company name and country';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.role in ('buyer', 'seller')
      and coalesce(p.account_status, 'active') = 'active'
  ) then
    raise exception 'This account is not eligible for initial role selection';
  end if;

  -- The account type and initial business details can only be selected before
  -- the account creates marketplace records or submits a membership payment.
  if exists (select 1 from public.products where seller_id = v_user_id)
     or exists (select 1 from public.rfqs where buyer_id = v_user_id)
     or exists (select 1 from public.buyer_requirements where buyer_id = v_user_id)
     or exists (select 1 from public.requirement_bids where seller_id = v_user_id)
     or exists (select 1 from public.seller_memberships where seller_id = v_user_id) then
    raise exception 'This account already has marketplace activity. Its existing role and business details were kept.';
  end if;

  update public.profiles
     set role = p_role,
         full_name = trim(p_full_name),
         company_name = trim(p_company_name),
         country = trim(p_country)
   where id = v_user_id
     and role in ('buyer', 'seller')
     and coalesce(account_status, 'active') = 'active';

  if not found then
    raise exception 'Profile could not be updated';
  end if;
end;
$$;

revoke all on function public.complete_my_oauth_profile(text, text, text, text) from public;
grant execute on function public.complete_my_oauth_profile(text, text, text, text) to authenticated;
