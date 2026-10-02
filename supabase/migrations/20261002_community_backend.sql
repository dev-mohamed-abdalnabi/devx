-- ذكر community backend
-- Apply once to the target Supabase project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-zA-Z0-9_]{3,30}$'),
  full_name text not null default '' check (char_length(full_name) between 0 and 80),
  bio text not null default '' check (char_length(bio) <= 280),
  avatar_url text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 5000),
  visibility text not null default 'public' check (visibility in ('public','followers','group')),
  group_id uuid,
  like_count integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  share_count integer not null default 0 check (share_count >= 0),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_shares (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  description text not null default '' check (char_length(description) <= 500),
  is_private boolean not null default false,
  member_count integer not null default 0 check (member_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

do $$ begin
  alter table public.posts add constraint posts_group_id_fkey foreign key (group_id) references public.groups(id) on delete set null;
exception when duplicate_object then null;
end $$;

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','moderator','member')),
  status text not null default 'active' check (status in ('active','pending','blocked')),
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null check (type in ('like','comment','share','follow','group_join','group_approved','mention','report_update')),
  post_id uuid references public.posts(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  reason text not null check (reason in ('spam','harassment','misinformation','inappropriate','other')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (num_nonnulls(post_id, comment_id, group_id) = 1)
);

create index if not exists posts_feed_idx on public.posts (created_at desc) where is_hidden = false;
create index if not exists posts_author_idx on public.posts (author_id, created_at desc);
create index if not exists comments_post_idx on public.comments (post_id, created_at);
create index if not exists notifications_user_idx on public.notifications (user_id, is_read, created_at desc);
create index if not exists reports_status_idx on public.reports (status, created_at desc);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare base_username text; candidate text; n integer := 0;
begin
  base_username := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1), 'member'), '[^a-zA-Z0-9_]', '', 'g'));
  if char_length(base_username) < 3 then base_username := 'member'; end if;
  candidate := left(base_username, 24);
  while exists (select 1 from public.profiles where username = candidate) loop
    n := n + 1; candidate := left(base_username, 24 - char_length(n::text)) || n::text;
  end loop;
  insert into public.profiles (id, username, full_name) values (new.id, candidate, coalesce(new.raw_user_meta_data->>'full_name', '')) on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists posts_updated_at on public.posts;
create trigger posts_updated_at before update on public.posts for each row execute function public.set_updated_at();
drop trigger if exists groups_updated_at on public.groups;
create trigger groups_updated_at before update on public.groups for each row execute function public.set_updated_at();
drop trigger if exists comments_updated_at on public.comments;
create trigger comments_updated_at before update on public.comments for each row execute function public.set_updated_at();

create or replace function public.refresh_post_counts() returns trigger language plpgsql security definer set search_path = public as $$
declare pid uuid := coalesce(new.post_id, old.post_id);
begin
  update public.posts set like_count = (select count(*) from public.post_likes where post_id = pid), share_count = (select count(*) from public.post_shares where post_id = pid), comment_count = (select count(*) from public.comments where post_id = pid) where id = pid;
  if tg_op = 'DELETE' then return old; else return new; end if;
end; $$;

drop trigger if exists post_likes_count on public.post_likes;
create trigger post_likes_count after insert or delete on public.post_likes for each row execute function public.refresh_post_counts();
drop trigger if exists post_shares_count on public.post_shares;
create trigger post_shares_count after insert or delete on public.post_shares for each row execute function public.refresh_post_counts();
drop trigger if exists comments_count on public.comments;
create trigger comments_count after insert or delete on public.comments for each row execute function public.refresh_post_counts();

create or replace function public.refresh_group_count() returns trigger language plpgsql security definer set search_path = public as $$
declare gid uuid := coalesce(new.group_id, old.group_id);
begin update public.groups set member_count = (select count(*) from public.group_members where group_id = gid and status = 'active') where id = gid; if tg_op = 'DELETE' then return old; else return new; end if; end; $$;
drop trigger if exists group_member_count on public.group_members;
create trigger group_member_count after insert or update or delete on public.group_members for each row execute function public.refresh_group_count();

create or replace function public.notify_post_like() returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid; begin select author_id into owner_id from public.posts where id = new.post_id; if owner_id <> new.user_id then insert into public.notifications(user_id, actor_id, type, post_id) values(owner_id, new.user_id, 'like', new.post_id); end if; return new; end; $$;
drop trigger if exists notify_like on public.post_likes;
create trigger notify_like after insert on public.post_likes for each row execute function public.notify_post_like();

create or replace function public.notify_comment() returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid; begin select author_id into owner_id from public.posts where id = new.post_id; if owner_id <> new.author_id then insert into public.notifications(user_id, actor_id, type, post_id, comment_id) values(owner_id, new.author_id, 'comment', new.post_id, new.id); end if; return new; end; $$;
drop trigger if exists notify_comment on public.comments;
create trigger notify_comment after insert on public.comments for each row execute function public.notify_comment();

create or replace function public.notify_follow() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.notifications(user_id, actor_id, type) values(new.following_id, new.follower_id, 'follow'); return new; end; $$;
drop trigger if exists notify_follow on public.follows;
create trigger notify_follow after insert on public.follows for each row execute function public.notify_follow();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.post_shares enable row level security;
alter table public.follows enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;

drop policy if exists profiles_read on public.profiles; create policy profiles_read on public.profiles for select using (true);
drop policy if exists profiles_self_update on public.profiles; create policy profiles_self_update on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists posts_read_public on public.posts; create policy posts_read_public on public.posts for select using (not is_hidden and (visibility = 'public' or author_id = auth.uid() or (visibility = 'followers' and exists(select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = author_id)) or (visibility = 'group' and exists(select 1 from public.group_members gm where gm.group_id = posts.group_id and gm.user_id = auth.uid() and gm.status = 'active'))));
drop policy if exists posts_insert_self on public.posts; create policy posts_insert_self on public.posts for insert with check (auth.uid() = author_id);
drop policy if exists posts_update_self on public.posts; create policy posts_update_self on public.posts for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists posts_delete_self on public.posts; create policy posts_delete_self on public.posts for delete using (auth.uid() = author_id);
drop policy if exists likes_read on public.post_likes; create policy likes_read on public.post_likes for select using (true);
drop policy if exists likes_self on public.post_likes; create policy likes_self on public.post_likes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists comments_read on public.comments; create policy comments_read on public.comments for select using (not is_hidden);
drop policy if exists comments_insert on public.comments; create policy comments_insert on public.comments for insert with check (auth.uid() = author_id);
drop policy if exists comments_self on public.comments; create policy comments_self on public.comments for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists shares_read on public.post_shares; create policy shares_read on public.post_shares for select using (true);
drop policy if exists shares_self on public.post_shares; create policy shares_self on public.post_shares for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists follows_read on public.follows; create policy follows_read on public.follows for select using (true);
drop policy if exists follows_self on public.follows; create policy follows_self on public.follows for all using (auth.uid() = follower_id) with check (auth.uid() = follower_id);
create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid()) returns boolean language sql security definer set search_path = public, pg_temp as $$ select exists (select 1 from public.group_members gm where gm.group_id = p_group_id and gm.user_id = p_user_id and gm.status = 'active'); $$;
revoke all on function public.is_group_member(uuid, uuid) from public; grant execute on function public.is_group_member(uuid, uuid) to anon, authenticated;
drop policy if exists groups_read on public.groups; create policy groups_read on public.groups for select using (not is_private or owner_id = auth.uid() or public.is_group_member(id, auth.uid()));
drop policy if exists groups_create on public.groups; create policy groups_create on public.groups for insert with check (auth.uid() = owner_id);
drop policy if exists groups_owner_update on public.groups; create policy groups_owner_update on public.groups for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists members_read on public.group_members; create policy members_read on public.group_members for select using (user_id = auth.uid() or public.is_group_member(group_id, auth.uid()));
drop policy if exists members_join on public.group_members; create policy members_join on public.group_members for insert with check (auth.uid() = user_id);
drop policy if exists members_self on public.group_members; create policy members_self on public.group_members for update using (auth.uid() = user_id or exists(select 1 from public.groups g where g.id = group_members.group_id and g.owner_id = auth.uid()));
drop policy if exists members_leave on public.group_members; create policy members_leave on public.group_members for delete using (auth.uid() = user_id or exists(select 1 from public.groups g where g.id = group_members.group_id and g.owner_id = auth.uid()));
drop policy if exists notifications_self on public.notifications; create policy notifications_self on public.notifications for select using (auth.uid() = user_id); drop policy if exists notifications_mark_read on public.notifications; create policy notifications_mark_read on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists reports_create on public.reports; create policy reports_create on public.reports for insert with check (auth.uid() = reporter_id);
drop policy if exists reports_self on public.reports; create policy reports_self on public.reports for select using (auth.uid() = reporter_id or exists(select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

-- Keep the relation names used by the Flutter queries stable.
comment on table public.posts is 'Text-only community posts for ذكر';
