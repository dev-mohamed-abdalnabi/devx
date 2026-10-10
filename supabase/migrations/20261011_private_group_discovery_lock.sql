-- Private groups must not be discoverable through the normal groups query.
-- They can only be found with the daily six-digit code.
alter table public.groups
  add column if not exists private_code_secret text not null default gen_random_uuid()::text;

create index if not exists groups_private_idx on public.groups (is_private);

create or replace function public.private_group_daily_code(
  p_secret text,
  p_day date default current_date
)
returns text
language sql
immutable
strict
as $$
  select lpad((abs(hashtextextended(p_secret || ':' || p_day::text, 0)) % 1000000)::text, 6, '0');
$$;

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
      or exists (
        select 1 from public.group_members gm
        where gm.group_id = g.id
          and gm.user_id = auth.uid()
          and gm.role = 'moderator'
          and gm.status = 'active'
      )
    );
$$;

revoke all on function public.private_group_daily_code(text, date) from public;
grant execute on function public.private_group_daily_code(text, date) to authenticated;
revoke all on function public.get_private_group_daily_code(uuid) from public;
grant execute on function public.get_private_group_daily_code(uuid) to authenticated;

create or replace function public.search_private_groups(p_code text)
returns table (
  id uuid,
  name text,
  description text,
  owner_id uuid,
  is_private boolean,
  member_count integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select g.id, g.name, g.description, g.owner_id, g.is_private, g.member_count
  from public.groups g
  where auth.uid() is not null
    and g.is_private
    and p_code ~ '^[0-9]{6}$'
    and public.private_group_daily_code(g.private_code_secret) = p_code
  order by g.name;
$$;

revoke all on function public.search_private_groups(text) from public;
grant execute on function public.search_private_groups(text) to authenticated;

-- No private group appears in the normal groups list, even to its owner/member.
drop policy if exists groups_read_safe on public.groups;
drop policy if exists groups_read on public.groups;
drop policy if exists groups_read_private_safe on public.groups;
create policy groups_read_public_only on public.groups
for select using (not is_private);

-- A private post is readable only by an active member. The author is not an exception.
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
            or public.is_group_member(g.id, auth.uid())
          )
      )
    )
  )
);

-- Comments on a private post are members-only as well.
drop policy if exists comments_read on public.comments;
create policy comments_read_group_safe on public.comments
for select using (
  exists (
    select 1 from public.posts p
    left join public.groups g on g.id = p.group_id
    where p.id = comments.post_id
      and (
        p.visibility <> 'group'
        or g is null
        or not g.is_private
        or public.is_group_member(g.id, auth.uid())
      )
  )
);

drop policy if exists comments_insert_own on public.comments;
create policy comments_insert_group_safe on public.comments
for insert with check (
  auth.uid() = author_id
  and exists (
    select 1 from public.posts p
    left join public.groups g on g.id = p.group_id
    where p.id = comments.post_id
      and (
        p.visibility <> 'group'
        or g is null
        or not g.is_private
        or public.is_group_member(g.id, auth.uid())
      )
  )
);
