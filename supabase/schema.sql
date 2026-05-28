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
  calendar_event_id text,
  -- v1.1 — 트리 / 메모 모델 컬럼
  parent_id         text,                                       -- 부모 todo id, null = root
  type              text not null default 'task',               -- 'task' | 'note'
  sort_order        integer not null default 0                  -- 같은 parent 내 사용자 정의 순서
);

-- ─────────────────────────────────────────────────────────────────────
-- v1.0 → v1.1 마이그레이션 (기존 환경 — schema.sql 이미 실행된 프로젝트)
--
-- 이미 v1.0 시점에 위 create table 을 실행한 프로젝트는 컬럼이 빠진 상태이므로
-- 아래 ALTER 3 줄을 SQL Editor 에서 한 번 실행. idempotent (`if not exists`).
-- 신규 셋업은 위 create table 이 처음부터 컬럼을 포함해 ALTER 불필요.
--
-- alter table solo_todo.todos add column if not exists parent_id  text;
-- alter table solo_todo.todos add column if not exists type       text not null default 'task';
-- alter table solo_todo.todos add column if not exists sort_order integer not null default 0;
-- ─────────────────────────────────────────────────────────────────────

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

-- ====================================================================
-- v1.2 — 카테고리 fully 동적 + Todo description
-- ====================================================================

-- 7) categories 테이블 (v1.2 신규)
create table if not exists solo_todo.categories (
  id              text primary key,
  user_id         uuid references auth.users(id) on delete cascade not null,
  label           text not null,
  icon_code_point integer not null,
  color_value     integer not null,
  sort_order      integer not null default 0,
  is_builtin      boolean not null default false,
  created_at      timestamptz not null default now()
);

grant all on solo_todo.categories to anon, authenticated, service_role;

-- 8) categories RLS — 본인 row 만 (todos 와 동일 패턴)
alter table solo_todo.categories enable row level security;
drop policy if exists "user_read_own_cat"   on solo_todo.categories;
drop policy if exists "user_insert_own_cat" on solo_todo.categories;
drop policy if exists "user_update_own_cat" on solo_todo.categories;
drop policy if exists "user_delete_own_cat" on solo_todo.categories;
create policy "user_read_own_cat"   on solo_todo.categories for select using (auth.uid() = user_id);
create policy "user_insert_own_cat" on solo_todo.categories for insert with check (auth.uid() = user_id);
create policy "user_update_own_cat" on solo_todo.categories for update using (auth.uid() = user_id);
create policy "user_delete_own_cat" on solo_todo.categories for delete using (auth.uid() = user_id);

-- 9) categories 정렬용 인덱스
create index if not exists categories_user_sort
  on solo_todo.categories (user_id, sort_order asc, created_at asc);

-- 10) categories Realtime publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'solo_todo' and tablename = 'categories'
  ) then
    alter publication supabase_realtime add table solo_todo.categories;
  end if;
end $$;

-- 11) todos.description 컬럼 (v1.2 신규)
alter table solo_todo.todos add column if not exists description text;

-- ─────────────────────────────────────────────────────────────────────
-- v1.1 → v1.2 마이그레이션 (기존 환경 — schema.sql 이미 실행된 프로젝트)
--
-- 이미 v1.1 시점에 위 create table / ALTER 까지 실행한 프로젝트는 categories
-- 테이블과 todos.description 컬럼이 빠진 상태이므로 아래 SQL 을 한 번 실행하면
-- 됩니다. 위 7~11 섹션이 idempotent (`if not exists` / `add column if not exists`)
-- 이므로 schema.sql 전체를 재실행해도 같은 결과입니다.
--
-- (별도 실행이 필요한 경우 위 7~11 섹션을 그대로 복사·실행. 단, RLS drop-then-
--  create 가 안전하게 재실행 됩니다.)
-- ─────────────────────────────────────────────────────────────────────
