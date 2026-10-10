-- Private groups are discoverable only through a daily six-digit code.
-- Public groups are readable without membership, but posting still requires active membership.

alter table public.groups
  add column if not exists private_code_secret text not null default gen_random_uuid()::text;

create index if not exists groups_private_idx on public.groups (is_private);

create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = p_user_id
      and gm.status = 'active'
  );
$$;
revoke all on function public.is_group_member(uuid, uuid) from public;
grant execute on function public.is_group_member(uuid, uuid) to anon, authenticated;

create or replace function public.private_group_daily_code(p_secret text, p_day date default current_date)
returns text
language sql
immutable
strict
as $$
  select lpad((abs(hashtextextended(p_secret || ':' || p_day::text, 0)) % 1000000)::text, 6, '0');
$$;

create or replace function public.search_private_groups(p_code text)
returns table (id uuid, name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select g.id, g.name
  from public.groups g
  where auth.uid() is not null
    and g.is_private
    and p_code ~ '^[0-9]{6}$'
    and public.private_group_daily_code(g.private_code_secret) = p_code
  order by g.name;
$$;

revoke all on function public.private_group_daily_code(text, date) from public;
grant execute on function public.private_group_daily_code(text, date) to authenticated;
revoke all on function public.search_private_groups(text) from public;
grant execute on function public.search_private_groups(text) to authenticated;

-- Public group posts are readable by everyone; private group posts remain members-only.
drop policy if exists posts_read_isolated on public.posts;
create policy posts_read_isolated on public.posts
for select using (
  not is_hidden and (
    visibility = 'public'
    or (
      visibility = 'followers'
      and exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
          and f.following_id = posts.author_id
      )
    )
    or (
      visibility = 'group'
      and group_id is not null
      and exists (
        select 1 from public.groups g
        where g.id = posts.group_id
          and (
            not g.is_private
            or g.owner_id = auth.uid()
            or exists (
              select 1 from public.group_members gm
              where gm.group_id = posts.group_id
                and gm.user_id = auth.uid()
                and gm.status = 'active'
            )
          )
      )
    )
  )
);

-- The normal groups list can show public groups and a user's own/active private groups.
drop policy if exists groups_read_safe on public.groups;
drop policy if exists groups_read on public.groups;
create policy groups_read_safe on public.groups
for select using (
  not is_private
  or owner_id = auth.uid()
  or public.is_group_member(id, auth.uid())
);

comment on function public.search_private_groups(text) is
  'Returns only id and name for a private group whose six-digit code matches today.';
