-- ============================================================
--  Daily dashboard for shops: database setup for Supabase
--  Paste this whole file into Supabase > SQL Editor > New query,
--  then press Run. It is safe to run only once on a new project.
-- ============================================================

-- ---------- tables ----------

create table public.businesses (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  join_code   text not null unique default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
  tz          text not null default 'Asia/Kolkata',
  created_by  uuid not null,
  created_at  timestamptz not null default now()
);

create table public.members (
  business_id  uuid not null references public.businesses(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         text not null check (role in ('owner', 'manager', 'staff')),
  status       text not null default 'active' check (status in ('active', 'pending')),
  display_name text not null default '',
  email        text not null default '',
  created_at   timestamptz not null default now(),
  primary key (business_id, user_id)
);

-- one business per person
create unique index members_one_business on public.members (user_id);

-- every entry, the shop profile and the spend categories live here
create table public.docs (
  business_id  uuid not null references public.businesses(id) on delete cascade,
  path         text not null,
  data         jsonb not null default '{}'::jsonb,
  updated_at   timestamptz not null default now(),
  primary key (business_id, path)
);

-- ---------- helper functions ----------

-- what role does the signed-in person have in this business?
create or replace function public.my_role(b uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.members m
  where m.business_id = b
    and m.user_id = auth.uid()
    and m.status = 'active'
  limit 1
$$;

-- today's date in the business's own time zone, written like 2026-10-09
create or replace function public.biz_today(b uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select to_char(
    (now() at time zone coalesce((select x.tz from public.businesses x where x.id = b), 'Asia/Kolkata'))::date,
    'YYYY-MM-DD'
  )
$$;

-- ---------- row level security: who can see and change what ----------

alter table public.businesses enable row level security;
alter table public.members    enable row level security;
alter table public.docs       enable row level security;

-- businesses: members can read, only the owner can change
create policy biz_select on public.businesses
  for select to authenticated
  using (public.my_role(id) is not null);

create policy biz_update on public.businesses
  for update to authenticated
  using (public.my_role(id) = 'owner')
  with check (public.my_role(id) = 'owner');

-- members: you see yourself, owners and managers see everyone in the business,
-- only the owner approves, changes or removes people
create policy mem_select on public.members
  for select to authenticated
  using (user_id = auth.uid() or public.my_role(business_id) in ('owner', 'manager'));

create policy mem_update on public.members
  for update to authenticated
  using (public.my_role(business_id) = 'owner' and role <> 'owner')
  with check (public.my_role(business_id) = 'owner' and role <> 'owner');

create policy mem_delete on public.members
  for delete to authenticated
  using (public.my_role(business_id) = 'owner' and role <> 'owner');

-- docs (entries, profile, categories)
--   owner:   everything
--   manager: all entries, can read the profile and categories
--   staff:   only TODAY's entry (read and write), plus the profile and categories (read only)
create policy docs_select on public.docs
  for select to authenticated
  using (
    public.my_role(business_id) in ('owner', 'manager')
    or (
      public.my_role(business_id) = 'staff'
      and (
        path in ('config/shop', 'config/spendCategories')
        or path = 'entries/' || public.biz_today(business_id)
      )
    )
  );

create policy docs_insert on public.docs
  for insert to authenticated
  with check (
    (public.my_role(business_id) in ('owner', 'manager') and path like 'entries/%')
    or (public.my_role(business_id) = 'owner' and path like 'config/%')
    or (public.my_role(business_id) = 'staff' and path = 'entries/' || public.biz_today(business_id))
  );

create policy docs_update on public.docs
  for update to authenticated
  using (
    (public.my_role(business_id) in ('owner', 'manager') and path like 'entries/%')
    or (public.my_role(business_id) = 'owner' and path like 'config/%')
    or (public.my_role(business_id) = 'staff' and path = 'entries/' || public.biz_today(business_id))
  )
  with check (
    (public.my_role(business_id) in ('owner', 'manager') and path like 'entries/%')
    or (public.my_role(business_id) = 'owner' and path like 'config/%')
    or (public.my_role(business_id) = 'staff' and path = 'entries/' || public.biz_today(business_id))
  );

create policy docs_delete on public.docs
  for delete to authenticated
  using (public.my_role(business_id) in ('owner', 'manager') and path like 'entries/%');

-- ---------- sign up helpers (run with the database's own permissions) ----------

-- an owner creates a new business
create or replace function public.create_business(p_name text, p_display text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_biz   uuid;
  v_email text;
begin
  if v_uid is null then
    raise exception 'You are not signed in';
  end if;
  if exists (select 1 from public.members where user_id = v_uid) then
    raise exception 'This account already belongs to a business';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'Enter the business name';
  end if;

  select u.email into v_email from auth.users u where u.id = v_uid;

  insert into public.businesses (name, created_by)
  values (trim(p_name), v_uid)
  returning id into v_biz;

  insert into public.members (business_id, user_id, role, status, display_name, email)
  values (v_biz, v_uid, 'owner', 'active', trim(coalesce(p_display, '')), coalesce(v_email, ''));

  insert into public.docs (business_id, path, data)
  values (v_biz, 'config/shop', jsonb_build_object(
    'name', trim(p_name),
    'owner', trim(coalesce(p_display, '')),
    'close', '18:00',
    'updated', (extract(epoch from now()) * 1000)::bigint
  ));

  return v_biz;
end;
$$;

-- staff ask to join a business with its code. The owner has to approve them.
create or replace function public.join_business(p_code text, p_display text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_biz   uuid;
  v_email text;
begin
  if v_uid is null then
    raise exception 'You are not signed in';
  end if;
  if exists (select 1 from public.members where user_id = v_uid) then
    raise exception 'This account already belongs to a business';
  end if;

  select b.id into v_biz
  from public.businesses b
  where b.join_code = upper(trim(coalesce(p_code, '')));

  if v_biz is null then
    raise exception 'That business code was not found';
  end if;

  select u.email into v_email from auth.users u where u.id = v_uid;

  insert into public.members (business_id, user_id, role, status, display_name, email)
  values (v_biz, v_uid, 'staff', 'pending', trim(coalesce(p_display, '')), coalesce(v_email, ''));

  return v_biz;
end;
$$;

-- who am I, and what is my status? (the owner also gets the join code)
create or replace function public.my_membership()
returns table (
  business_id   uuid,
  business_name text,
  role          text,
  status        text,
  join_code     text,
  display_name  text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.business_id,
    b.name,
    m.role,
    m.status,
    case when m.role = 'owner' and m.status = 'active' then b.join_code else null end,
    m.display_name
  from public.members m
  join public.businesses b on b.id = m.business_id
  where m.user_id = auth.uid()
  limit 1
$$;

-- the owner makes a fresh join code (the old one stops working)
create or replace function public.new_join_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_biz  uuid;
  v_code text;
begin
  select m.business_id into v_biz
  from public.members m
  where m.user_id = auth.uid() and m.role = 'owner' and m.status = 'active';

  if v_biz is null then
    raise exception 'Only the owner can do this';
  end if;

  update public.businesses
  set join_code = upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))
  where id = v_biz
  returning join_code into v_code;

  return v_code;
end;
$$;

-- ---------- permissions ----------

revoke all on public.businesses, public.members, public.docs from anon;
grant select, update                 on public.businesses to authenticated;
grant select, update, delete         on public.members    to authenticated;
grant select, insert, update, delete on public.docs       to authenticated;

revoke execute on function public.my_role(uuid)                from public, anon;
revoke execute on function public.biz_today(uuid)              from public, anon;
revoke execute on function public.create_business(text, text)  from public, anon;
revoke execute on function public.join_business(text, text)    from public, anon;
revoke execute on function public.my_membership()              from public, anon;
revoke execute on function public.new_join_code()              from public, anon;

grant execute on function public.my_role(uuid)                to authenticated;
grant execute on function public.biz_today(uuid)              to authenticated;
grant execute on function public.create_business(text, text)  to authenticated;
grant execute on function public.join_business(text, text)    to authenticated;
grant execute on function public.my_membership()              to authenticated;
grant execute on function public.new_join_code()              to authenticated;

-- ---------- live updates between devices ----------

alter table public.docs replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.docs;
exception when others then
  null; -- already added
end;
$$;

-- ---------- quick check (optional) ----------
-- After running, this should return 3 tables and 9 policies:
--   select (select count(*) from pg_tables where schemaname = 'public' and tablename in ('businesses','members','docs')) as tables,
--          (select count(*) from pg_policies where schemaname = 'public') as policies;
