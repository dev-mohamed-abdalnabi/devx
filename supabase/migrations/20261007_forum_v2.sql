-- المنتدى v2 (المرحلة 1): ردود على التعليقات، لايك للتعليق، جرس الإشعارات بدل المتابعة.

-- توافق مع مخطط المشروع الحالي قبل إضافة وظائف المرحلة الثانية.
alter table public.posts add column if not exists is_hidden boolean not null default false;
alter table public.notifications add column if not exists comment_id uuid references public.comments(id) on delete cascade;

-- 1) ردود التعليقات + لايك التعليق
alter table public.comments add column if not exists parent_id uuid references public.comments(id) on delete cascade;
alter table public.comments add column if not exists like_count integer not null default 0 check (like_count >= 0);
create index if not exists comments_parent_idx on public.comments (parent_id);

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
alter table public.comment_likes enable row level security;
drop policy if exists comment_likes_read on public.comment_likes;
create policy comment_likes_read on public.comment_likes for select using (true);
drop policy if exists comment_likes_self on public.comment_likes;
create policy comment_likes_self on public.comment_likes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.refresh_comment_likes() returns trigger language plpgsql security definer set search_path = public as $$
declare cid uuid := coalesce(new.comment_id, old.comment_id);
begin
  update public.comments set like_count = (select count(*) from public.comment_likes where comment_id = cid) where id = cid;
  if tg_op = 'DELETE' then return old; else return new; end if;
end; $$;
drop trigger if exists comment_likes_count on public.comment_likes;
create trigger comment_likes_count after insert or delete on public.comment_likes for each row execute function public.refresh_comment_likes();

-- حذف التعليق (صاحبه أو أدمن) وحذف الإشعارات الخاصة بالمستخدم
drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments for delete using (auth.uid() = author_id or public.current_user_is_admin());
drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications for delete using (auth.uid() = user_id);

-- 2) أنواع إشعارات جديدة
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like','comment','reply','comment_like','new_post','share','follow','group_join','group_approved','mention','report_update'));

-- 3) المتابعة صارت «جرس»: لا إشعار عند الضغط، بل إشعار عند كل منشور جديد
drop trigger if exists notify_follow on public.follows;

create or replace function public.notify_subscribers() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.visibility in ('public','followers') and not new.is_hidden then
    insert into public.notifications(user_id, actor_id, type, post_id)
    select f.follower_id, new.author_id, 'new_post', new.id from public.follows f where f.following_id = new.author_id;
  end if;
  return new;
end; $$;
drop trigger if exists notify_new_post on public.posts;
create trigger notify_new_post after insert on public.posts for each row execute function public.notify_subscribers();

-- 4) إشعار التعليق/الرد
create or replace function public.notify_comment() returns trigger language plpgsql security definer set search_path = public as $$
declare post_owner uuid; parent_owner uuid;
begin
  select author_id into post_owner from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select author_id into parent_owner from public.comments where id = new.parent_id;
    if parent_owner <> new.author_id then
      insert into public.notifications(user_id, actor_id, type, post_id, comment_id) values(parent_owner, new.author_id, 'reply', new.post_id, new.id);
    end if;
  end if;
  if post_owner <> new.author_id and post_owner is distinct from parent_owner then
    insert into public.notifications(user_id, actor_id, type, post_id, comment_id) values(post_owner, new.author_id, 'comment', new.post_id, new.id);
  end if;
  return new;
end; $$;

create or replace function public.notify_comment_like() returns trigger language plpgsql security definer set search_path = public as $$
declare owner uuid; pid uuid;
begin
  select author_id, post_id into owner, pid from public.comments where id = new.comment_id;
  if owner <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, post_id, comment_id) values(owner, new.user_id, 'comment_like', pid, new.comment_id);
  end if;
  return new;
end; $$;
drop trigger if exists notify_comment_like on public.comment_likes;
create trigger notify_comment_like after insert on public.comment_likes for each row execute function public.notify_comment_like();

-- 5) Realtime للإشعارات (يستخدمها التطبيق لإظهار إشعار أندرويد فوري)
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null;
end $$;
