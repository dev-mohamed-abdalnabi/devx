-- Recreate the private-group code RPC with the current authorization rules.
-- Only the group owner or a trusted app admin may retrieve the daily code.
create or replace function public.get_private_group_daily_code(p_group_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.private_group_daily_code(g.private_code_secret)
  from public.groups g
  where g.id = p_group_id
    and (
      g.owner_id = auth.uid()
      or coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false)
    );
$$;

revoke all on function public.get_private_group_daily_code(uuid) from public;
grant execute on function public.get_private_group_daily_code(uuid) to authenticated;

-- Ensure PostgREST exposes the recreated RPC immediately.
select pg_notify('pgrst', 'reload schema');
