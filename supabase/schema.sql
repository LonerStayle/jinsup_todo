-- Solo Todo — 신규 Supabase 셋업 SQL
-- Supabase Dashboard → Database → SQL Editor 에 붙여넣고 실행.
-- 여러 번 실행해도 안전 (idempotent).
--
-- 무료 플랜 1 프로젝트를 다른 앱과 공유할 수 있도록 별도 schema 'solo_todo' 에 격리.
-- ⚠️ 실행 후 Settings → API → Exposed schemas 에 'solo_todo' 를 반드시 추가하십시오.

-- 1) schema
create schema if not exists solo_todo;

-- 2) role 권한 (PostgREST + Realtime 이 쓰는 role 들)
grant usage on schema solo_todo to anon, authenticated, service_role;
alter default privileges in schema solo_todo
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema solo_todo
  grant all on sequences to anon, authenticated, service_role;

-- 3) todos 테이블
create table if not exists solo_todo.todos (
  id                text primary key,
  user_id           uuid references auth.users(id) on delete cascade not null,
  title             text not null,
  category          text not null,
  due_at            timestamptz,
  done_at           timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  calendar_event_id text
);

-- 이미 만든 테이블에도 grant (default privileges 는 이후 생성 객체에만 적용)
grant all on solo_todo.todos to anon, authenticated, service_role;

-- 4) RLS — 본인 row 만. drop-then-create 로 재실행 안전.
alter table solo_todo.todos enable row level security;
drop policy if exists "user_read_own"   on solo_todo.todos;
drop policy if exists "user_insert_own" on solo_todo.todos;
drop policy if exists "user_update_own" on solo_todo.todos;
drop policy if exists "user_delete_own" on solo_todo.todos;
create policy "user_read_own"   on solo_todo.todos for select using (auth.uid() = user_id);
create policy "user_insert_own" on solo_todo.todos for insert with check (auth.uid() = user_id);
create policy "user_update_own" on solo_todo.todos for update using (auth.uid() = user_id);
create policy "user_delete_own" on solo_todo.todos for delete using (auth.uid() = user_id);

-- 5) 동기화 정렬용 인덱스
create index if not exists todos_user_updated
  on solo_todo.todos (user_id, updated_at desc);

-- 6) Realtime publication 에 추가. 이미 멤버면 42710 에러나므로 조건부.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'solo_todo' and tablename = 'todos'
  ) then
    alter publication supabase_realtime add table solo_todo.todos;
  end if;
end $$;
