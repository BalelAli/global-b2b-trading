-- Global B2B Trading: harden the private buyer-requirements admin RPC.
-- Safe to re-run. Does not change marketplace data.

create or replace function public.admin_list_requirements()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'balelali953@gmail.com'
     or not exists (
       select 1 from public.profiles a
       where a.id = auth.uid() and a.role = 'admin'
     ) then
    raise exception 'Not authorized to view all buyer requirements';
  end if;

  return query
    select to_jsonb(br)
    from public.buyer_requirements br
    order by br.created_at desc;
end;
$$;

revoke all on function public.admin_list_requirements() from public, anon;
grant execute on function public.admin_list_requirements() to authenticated;
