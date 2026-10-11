-- Trusted admins may manage private-group membership requests too.
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
  if p_status not in ('active', 'blocked') then raise exception 'invalid_membership_status'; end if;
  if p_target_user_id = actor then raise exception 'self_approval_forbidden'; end if;
  if not exists (
    select 1 from public.groups g
    where g.id = p_group_id
      and (
        g.owner_id = actor
        or coalesce((select p.is_admin from public.profiles p where p.id = actor), false)
        or exists (
          select 1 from public.group_members gm
          where gm.group_id = p_group_id
            and gm.user_id = actor
            and gm.role = 'moderator'
            and gm.status = 'active'
        )
      )
  ) then raise exception 'group_membership_manager_required'; end if;

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
revoke all on function public.approve_group_membership(uuid, uuid, text) from public;
grant execute on function public.approve_group_membership(uuid, uuid, text) to authenticated;
