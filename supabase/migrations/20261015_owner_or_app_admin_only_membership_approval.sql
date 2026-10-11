-- Only the group owner or a trusted app admin may view/manage pending requests.
-- Moderators and ordinary active members must not be able to approve, block,
-- delete, or read other users' pending membership requests.

create or replace function public.can_manage_group_members(
  p_group_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p_user_id is not null
    and (
      coalesce((select p.is_admin from public.profiles p where p.id = p_user_id), false)
      or exists (
        select 1
        from public.groups g
        where g.id = p_group_id
          and g.owner_id = p_user_id
      )
    );
$$;

create or replace function public.approve_group_membership(
  p_group_id uuid,
  p_target_user_id uuid,
  p_status text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  changed integer;
begin
  if actor is null then raise exception 'not_authenticated'; end if;
  if p_status not in ('active', 'blocked') then
    raise exception 'invalid_membership_status';
  end if;
  if p_target_user_id = actor then
    raise exception 'self_approval_forbidden';
  end if;
  if not public.can_manage_group_members(p_group_id, actor) then
    raise exception 'group_membership_manager_required';
  end if;

  update public.group_members
  set status = p_status
  where group_id = p_group_id
    and user_id = p_target_user_id
    and role = 'member'
    and status = 'pending';

  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'pending_membership_not_found'; end if;
  return true;
end;
$$;

revoke all on function public.can_manage_group_members(uuid, uuid) from public;
grant execute on function public.can_manage_group_members(uuid, uuid) to authenticated;
revoke all on function public.approve_group_membership(uuid, uuid, text) from public;
grant execute on function public.approve_group_membership(uuid, uuid, text) to authenticated;

-- The RPC was added after PostgREST's schema cache was built in some deployments.
notify pgrst, 'reload schema';
