-- Ensure every supported interaction creates a notification.
alter table public.comments add column if not exists parent_id uuid references public.comments(id) on delete cascade;
alter table public.comments add column if not exists like_count integer not null default 0;
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

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('like','comment','reply','comment_like','new_post','share','follow','group_join','group_approved','mention','report_update'));

create or replace function public.notify_comment_like()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  owner_id uuid;
  post_owner uuid;
  post_id_value uuid;
begin
  select c.author_id, p.author_id, c.post_id
    into owner_id, post_owner, post_id_value
  from public.comments c
  join public.posts p on p.id = c.post_id
  where c.id = new.comment_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, post_id, comment_id)
    values (owner_id, new.user_id, 'comment_like', post_id_value, new.comment_id);
  end if;
  return new;
end;
$$;

drop trigger if exists notify_comment_like on public.comment_likes;
create trigger notify_comment_like
after insert on public.comment_likes
for each row execute function public.notify_comment_like();

create or replace function public.notify_comment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  post_owner uuid;
  parent_owner uuid;
begin
  select author_id into post_owner from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select author_id into parent_owner from public.comments where id = new.parent_id;
    if parent_owner is not null and parent_owner <> new.author_id then
      insert into public.notifications(user_id, actor_id, type, post_id, comment_id)
      values (parent_owner, new.author_id, 'reply', new.post_id, new.id);
    end if;
  end if;
  if post_owner is not null and post_owner <> new.author_id
     and post_owner is distinct from parent_owner then
    insert into public.notifications(user_id, actor_id, type, post_id, comment_id)
    values (post_owner, new.author_id, 'comment', new.post_id, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists notify_comment on public.comments;
create trigger notify_comment after insert on public.comments
for each row execute function public.notify_comment();

-- Keep the list screen fresh while it is open; realtime publication is already enabled.
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null;
end $$;
