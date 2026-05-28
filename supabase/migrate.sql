-- Solo Todo — 마이그레이션 SQL (이전 버전 SQL 을 이미 실행했던 경우)
--
-- 이전 단계에서 아래 둘 중 하나로 실행한 적이 있다면 schema 'solo_todo' 로 이동:
--   - public.todos          (가장 첫 버전)
--   - public.solo_todo_todos (prefix 버전)
-- 둘 다 없으면 모든 블록이 no-op 으로 안전하게 통과.
--
-- 실행 순서: schema.sql 의 'create schema if not exists solo_todo;' 가 먼저 실행돼 있어야 함.
-- (schema.sql 을 통째로 먼저 실행했다면 이미 충족.)

create schema if not exists solo_todo;

do $$
begin
  -- Case A: public.todos
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'todos'
  ) then
    alter table public.todos set schema solo_todo;
  end if;

  -- Case B: public.solo_todo_todos → solo_todo.todos
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'solo_todo_todos'
  ) then
    alter table public.solo_todo_todos set schema solo_todo;
    alter table solo_todo.solo_todo_todos rename to todos;
  end if;
end $$;

-- 옮긴 객체에 grant (role 들이 schema 접근 가능하도록)
grant usage on schema solo_todo to anon, authenticated, service_role;
grant all on solo_todo.todos to anon, authenticated, service_role;

-- Realtime publication 재매핑: 옛 public 매핑 제거 후 새 schema 의 테이블 등록.
alter publication supabase_realtime drop table if exists public.todos;
alter publication supabase_realtime drop table if exists public.solo_todo_todos;
alter publication supabase_realtime add  table solo_todo.todos;
