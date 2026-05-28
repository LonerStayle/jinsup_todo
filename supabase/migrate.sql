-- Solo Todo — 정리(cleanup) SQL
--
-- 이전 버전에서 public schema 에 잘못 만들었던 테이블을 삭제한다.
--   - public.todos            (가장 첫 버전)
--   - public.solo_todo_todos  (prefix 버전)
-- 초기 셋업 단계라 실데이터가 없다는 전제. (데이터 보존이 필요하면 drop 대신
-- `alter table ... set schema solo_todo` 로 옮겨야 함 — 지금은 깔끔히 삭제.)
--
-- 실행 순서: 이 파일(정리) 먼저 → 그 다음 schema.sql(신규 생성).

-- 1) publication 에서 먼저 제거. ALTER PUBLICATION 은 IF EXISTS 미지원 →
--    pg_publication_tables 카탈로그 확인 후 조건부.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'todos'
  ) then
    alter publication supabase_realtime drop table public.todos;
  end if;

  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'solo_todo_todos'
  ) then
    alter publication supabase_realtime drop table public.solo_todo_todos;
  end if;
end $$;

-- 2) 옛 테이블 삭제 (policy / index 함께 cascade). 없으면 no-op.
drop table if exists public.todos cascade;
drop table if exists public.solo_todo_todos cascade;
