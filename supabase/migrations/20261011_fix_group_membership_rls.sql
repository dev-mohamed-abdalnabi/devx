-- Final hardening for private-group membership requests.
-- PostgreSQL combines policies with OR, so remove every legacy membership
-- policy before creating the authoritative set below.
drop policy if exists members_insert on public.group_members;
drop policy if exists members_insert_self on public.group_members;
drop policy if exists members_join on public.group_members;
drop policy if exists members_insert_safe on public.group_members;
drop policy if exists members_insert_hardened on public.group_members;
drop policy if exists members_select on public.group_members;
drop policy if exists members_read on public.group_members;
drop policy if exists members_select_hardened on public.group_members;
drop policy if exists members_update on public.group_members;
drop policy if exists members_self on public.group_members;
drop policy if exists members_update_hardened on public.group_members;
drop policy if exists members_leave on public.group_members;
drop policy if exists members_delete on public.group_members;
drop policy if exists members_delete_hardened on public.group_members;

-- Only the group owner, an active moderator/owner, or a trusted admin may
-- approve/reject another member. A requester can never approve itself.
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
        select 1 from public.groups g
        where g.id = p_group_id and g.owner_id = p_user_id
      )
      or exists (
        select 1 from public.group_members gm
        where gm.group_id = p_group_id
          and gm.user_id = p_user_id
          and gm.role in ('owner', 'moderator')
          and gm.status = 'active'
      )
    );
$$;

revoke all on function public.can_manage_group_members(uuid, uuid) from public;
grant execute on function public.can_manage_group_members(uuid, uuid) to authenticated;

create policy members_insert_authoritative on public.group_members
for insert with check (
  auth.uid() = user_id
  and role = 'member'
  and status = case when exists (
    select 1 from public.groups g
    where g.id = group_members.group_id and g.is_private
  ) then 'pending' else 'active' end
);

create policy members_select_authoritative on public.group_members
for select using (
  user_id = auth.uid()
  or public.is_group_member(group_id, auth.uid())
  or public.can_manage_group_members(group_id, auth.uid())
);

create policy members_update_authoritative on public.group_members
for update using (
  role <> 'owner'
  and public.can_manage_group_members(group_id, auth.uid())
)
with check (
  role in ('member', 'moderator')
  and status in ('active', 'pending', 'blocked')
  and public.can_manage_group_members(group_id, auth.uid())
);

create policy members_delete_authoritative on public.group_members
for delete using (
  role <> 'owner'
  and (
    (auth.uid() = user_id and status <> 'blocked')
    or public.can_manage_group_members(group_id, auth.uid())
  )
);
