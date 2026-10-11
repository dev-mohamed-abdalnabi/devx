-- Private groups are visible in the normal list only to their owner,
-- active members, or trusted admins. Non-members can use the daily code search.
drop policy if exists groups_read_public_only on public.groups;
drop policy if exists groups_read_private_members on public.groups;
create policy groups_read_private_members on public.groups
for select using (
  not is_private
  or owner_id = auth.uid()
  or public.is_group_member(id, auth.uid())
  or coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false)
);
