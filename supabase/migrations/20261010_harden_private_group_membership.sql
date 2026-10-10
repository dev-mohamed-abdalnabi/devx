-- Harden private-group visibility and membership approval.
-- PostgreSQL combines policies with OR, so all legacy policies are removed first.
drop policy if exists members_insert on public.group_members;
drop policy if exists members_insert_self on public.group_members;
drop policy if exists members_join on public.group_members;
drop policy if exists members_insert_safe on public.group_members;
drop policy if exists members_select on public.group_members;
drop policy if exists members_read on public.group_members;
drop policy if exists members_update on public.group_members;
drop policy if exists members_self on public.group_members;
drop policy if exists members_leave on public.group_members;
drop policy if exists members_delete on public.group_members;
drop policy if exists groups_select on public.groups;
drop policy if exists groups_read on public.groups;
drop policy if exists groups_read_safe on public.groups;

create policy groups_read_private_safe on public.groups for select using (
  not is_private
  or owner_id = auth.uid()
  or public.is_group_member(id, auth.uid())
  or private.is_admin()
);

create policy members_insert_hardened on public.group_members
for insert with check (
  auth.uid() = user_id
  and role = 'member'
  and status = case when (select g.is_private from public.groups g where g.id = group_members.group_id) then 'pending' else 'active' end
);

create policy members_select_hardened on public.group_members
for select using (
  user_id = auth.uid()
  or public.is_group_member(group_id, auth.uid())
  or private.is_admin()
);

create policy members_update_hardened on public.group_members
for update using (
  role <> 'owner'
  and (private.is_group_mod(group_id) or private.is_admin())
)
with check (
  role in ('member','moderator')
  and status in ('active','pending','blocked')
  and (private.is_group_mod(group_id) or private.is_admin())
);

create policy members_delete_hardened on public.group_members
for delete using (
  role <> 'owner'
  and ((auth.uid() = user_id and status <> 'blocked') or private.is_group_mod(group_id) or private.is_admin())
);

-- Existing private memberships created through the old permissive policy must be approved again.
update public.group_members gm
set status = 'pending', role = 'member'
from public.groups g
where g.id = gm.group_id
  and g.is_private
  and gm.role <> 'owner'
  and not (gm.user_id = g.owner_id);

insert into public.group_members (group_id, user_id, role, status)
select g.id, g.owner_id, 'owner', 'active'
from public.groups g
where not exists (select 1 from public.group_members gm where gm.group_id = g.id and gm.user_id = g.owner_id)
on conflict (group_id, user_id) do update set role = 'owner', status = 'active';
