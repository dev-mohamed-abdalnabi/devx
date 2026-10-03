-- Group feed and community security hardening.
-- Apply after 20261002_community_backend.sql.

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

-- Centralized, server-side admin check for RLS policies.
create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

revoke all on function public.current_user_is_admin() from public;
grant execute on function public.current_user_is_admin() to authenticated;

-- A client must never be able to promote itself by updating profiles.is_admin.
create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' and new.is_admin is distinct from old.is_admin then
    raise exception 'is_admin can only be changed by the service role';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_privilege_escalation on public.profiles;
create trigger profiles_prevent_privilege_escalation
before update on public.profiles
for each row execute function public.prevent_profile_privilege_escalation();

-- Group posts can only be created by an active member (or the group owner).
drop policy if exists posts_insert_self on public.posts;
create policy posts_insert_self on public.posts
for insert with check (
  auth.uid() = author_id
  and (
    visibility <> 'group'
    or (
      group_id is not null
      and exists (
        select 1 from public.group_members gm
        where gm.group_id = posts.group_id
          and gm.user_id = auth.uid()
          and gm.status = 'active'
      )
    )
  )
);

-- Authors can delete their own posts; trusted admins can moderate any post.
drop policy if exists posts_delete_self on public.posts;
create policy posts_delete_self on public.posts
for delete using (auth.uid() = author_id or public.current_user_is_admin());

-- Keep group posts internally consistent.
alter table public.posts drop constraint if exists posts_group_visibility_check;
alter table public.posts add constraint posts_group_visibility_check
check (visibility <> 'group' or group_id is not null);

comment on function public.current_user_is_admin() is 'RLS-only admin check; the client cannot grant itself admin privileges.';
