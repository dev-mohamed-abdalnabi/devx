-- عزل منشورات الجروبات وتشديد طلبات العضوية.

-- لا توجد منشورات جروب بلا جروب مرتبط، ولا يمكن إخفاء منشور ثم تسريبه للفيد.
alter table public.posts drop constraint if exists posts_group_visibility_check;
alter table public.posts add constraint posts_group_visibility_check
  check (visibility <> 'group' or group_id is not null);

-- إزالة السياسات القديمة المتداخلة؛ سياسات PostgreSQL المتعددة تعمل بمنطق OR.
drop policy if exists posts_read on public.posts;
drop policy if exists posts_read_public on public.posts;
drop policy if exists posts_insert_own on public.posts;
drop policy if exists posts_insert_self on public.posts;
drop policy if exists posts_update_own on public.posts;
drop policy if exists posts_update_self on public.posts;
drop policy if exists posts_delete_own on public.posts;
drop policy if exists posts_delete_self on public.posts;

-- الفيد العام يرى public، وfollowers للمشتركين فقط؛ منشورات group لا تظهر إلا لعضو نشط.
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
      and (
        author_id = auth.uid()
        or exists (
          select 1 from public.group_members gm
          where gm.group_id = posts.group_id
            and gm.user_id = auth.uid()
            and gm.status = 'active'
        )
      )
    )
  )
);

-- لا يمكن إنشاء منشور جروب إلا لعضو نشط، ولا يمكن ربط منشور عام بجروب.
create policy posts_insert_isolated on public.posts
for insert with check (
  auth.uid() = author_id
  and (
    (visibility in ('public', 'followers') and group_id is null)
    or (
      visibility = 'group'
      and group_id is not null
      and exists (
        select 1 from public.group_members gm
        where gm.group_id = posts.group_id
          and gm.user_id = auth.uid()
          and gm.status = 'active'
      )
    )
  )
);

create policy posts_update_isolated on public.posts
for update using (auth.uid() = author_id)
with check (
  auth.uid() = author_id
  and (
    (visibility in ('public', 'followers') and group_id is null)
    or (
      visibility = 'group'
      and group_id is not null
      and exists (
        select 1 from public.group_members gm
        where gm.group_id = posts.group_id
          and gm.user_id = auth.uid()
          and gm.status = 'active'
      )
    )
  )
);

create policy posts_delete_isolated on public.posts
for delete using (auth.uid() = author_id or public.current_user_is_admin());

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

-- منع العميل من تزوير owner/moderator أو منح نفسه عضوية active في جروب خاص.
drop policy if exists members_insert_self on public.group_members;
create policy members_insert_safe on public.group_members
for insert with check (
  auth.uid() = user_id
  and role = 'member'
  and exists (
    select 1 from public.groups g
    where g.id = group_members.group_id
      and status = case when g.is_private then 'pending' else 'active' end
  )
);

-- العضو المحظور أو صاحب الطلب المعلق لا يقرأ تفاصيل الجروب الخاص.
drop policy if exists groups_read on public.groups;
create policy groups_read_safe on public.groups
for select using (
  not is_private
  or owner_id = auth.uid()
  or public.is_group_member(id, auth.uid())
);
