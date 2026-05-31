-- date-repeat (v7) — 할 일 날짜 반복
--
-- 기존 Supabase todos 테이블에 반복 시리즈 컬럼 4종을 추가한다.
-- 모두 idempotent (`if not exists`) — 여러 번 실행해도 안전.
-- RLS 변경 불필요(기존 auth.uid() = user_id 그대로). Realtime publication 변경 불필요.

alter table todos add column if not exists series_id text;
alter table todos add column if not exists recurrence_rule text;
alter table todos add column if not exists recurrence_end_at timestamptz;
alter table todos add column if not exists is_series_master boolean not null default false;

-- 시리즈 단위 조회(인스턴스 묶음/마스터 lookup) 가속.
create index if not exists todos_series_idx on todos (user_id, series_id);
