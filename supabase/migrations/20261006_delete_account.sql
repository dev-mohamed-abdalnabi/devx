-- مسح الحساب: يحذف المستخدم الحالي نهائيًا مع كل بياناته (cascade).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  -- الجروبات التي يملكها تُحذف تلقائيًا (groups.owner_id on delete cascade)
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- المنتدى: فهرس لتسريع الفيد العام بدون منشورات الجروبات
create index if not exists posts_public_feed_idx
  on public.posts (created_at desc)
  where is_hidden = false and visibility <> 'group';
