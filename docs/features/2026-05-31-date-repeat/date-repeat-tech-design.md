# 기술 설계: 할 일 날짜 반복 (date-repeat)

> 상위 문서: `date-repeat-requirements.md` (PRD). 본 문서는 기술 결정·구현 방향. 구체 task 분해는 다음 단계 `date-repeat-implementation-plan.md`.

## 0. 설계 요약 (한눈에)

- **마스터-인스턴스 모델**: 반복 규칙은 "마스터 Todo"(숨김 템플릿)가 보유. 발생일마다 실제 "인스턴스 Todo"를 생성. 인스턴스는 일반 Todo와 100% 동일하게 동작 → 기존 이월/오늘/동기화 로직을 그대로 재사용.
- **lazy 생성(materializer)**: 앱 시작 + 자정 롤오버(`currentDayProvider`) 시, 각 활성 마스터에 대해 마지막 생성일~오늘까지 누락 인스턴스를 idempotent 하게 채움. 미래분은 미리 만들지 않음.
- **이월(FR-3)**: 인스턴스가 `dueAt` 가진 일반 Todo이므로 `CarryoverPolicy` 가 자동 처리.
- **dedup 표시(FR-4)**: '오늘 할 일' 빌드 시 같은 `seriesId` 미체크 인스턴스를 묶어 **가장 오래된 1건만** 노출 + 묶음 배지. 데이터는 보존.
- **캘린더(FR-8)**: 마스터가 단일 RRULE 이벤트 1개를 소유. 인스턴스는 개별 캘린더 이벤트를 만들지 않음.

## 1. 아키텍처 / 영향 컴포넌트

| 레이어 | 파일 | 변경 |
|---|---|---|
| 도메인 모델 | `lib/src/domain/todo.dart` | 반복 필드 추가 (`seriesId`, `recurrenceRule`, `recurrenceEndAt`, `isSeriesMaster`) |
| 반복 규칙 값객체 | `lib/src/domain/recurrence.dart` (신규) | `RecurrenceRule`(freq/interval/byWeekday) + 다음 발생일 계산 + RRULE 직렬화 |
| 가시성 정책 | `lib/src/domain/policies/visibility_policy.dart` | 마스터는 모든 목록에서 제외 |
| dedup 정책 | `lib/src/domain/policies/recurrence_dedup_policy.dart` (신규) | 오늘 목록의 series 묶음 처리 |
| materializer | `lib/src/domain/recurrence_materializer.dart` (신규) | 누락 인스턴스 생성(순수 함수) |
| materializer 트리거 | `lib/src/features/home/today_providers.dart` + `day_boundary_provider.dart` | 앱시작/자정에 materialize 호출 |
| 로컬 스키마 | `lib/src/data/local/app_database.dart` | Drift schemaVersion 6→7, 컬럼 4개 추가(ALTER idempotent) |
| 원격 스키마 | `supabase/schema.sql` + 마이그레이션 | todos 컬럼 4개 추가 |
| 매핑 | `lib/src/data/remote/supabase_todos_api.dart` | camelCase↔snake_case 신규 필드 |
| 캘린더 | `lib/src/features/calendar/calendar_service.dart` | `buildEvent` 에 RRULE 세팅(마스터 한정) |
| UI 입력 | `add_todo` 시트 / 편집 시트 | 반복 규칙 선택 UI(주기·간격·요일·종료일) |
| UI 표시 | 오늘 목록 아이템 | 반복 아이콘(FR-7) + dedup 배지 |

## 2. 데이터 모델

### 2.1 Todo 신규 필드

| 필드 | 타입 | 의미 |
|---|---|---|
| `seriesId` | String? | 소속 반복 시리즈 id. 마스터는 자기 id, 인스턴스는 마스터 id. null = 일반 Todo |
| `recurrenceRule` | String? | 반복 규칙 직렬화(RRULE 부분집합). **마스터에만** 채움 |
| `recurrenceEndAt` | DateTime? | 반복 종료일. **마스터에만**. null = 무한 |
| `isSeriesMaster` | bool | true = 규칙 보유 숨김 템플릿. 기본 false |

> 결정: **별도 recurrence_rules 테이블 대신 todos 컬럼 확장**.
> 대안 비교 — (A) todos 컬럼 확장: 기존 단일 테이블 sync/outbox/RLS 경로를 그대로 재사용, 마이그레이션 단순. (B) 별도 테이블: 정규화는 깔끔하나 sync 경로·RLS·Drift DAO를 새로 만들어야 함(1인 앱엔 과설계). → **(A) 채택.**

### 2.2 RecurrenceRule 값객체 (`recurrence.dart`)

```dart
enum RecurrenceFreq { daily, weekly, monthly, yearly }

class RecurrenceRule {
  final RecurrenceFreq freq;
  final int interval;            // N간격 (1 이상). 예: weekly+interval2 = 2주마다
  final Set<int> byWeekday;      // weekly 전용 (1=Mon..7=Sun). 비면 anchor 요일
  // monthly 는 anchor 일자, yearly 는 anchor 월/일 사용 (별도 필드 불요)

  DateTime nextOccurrence(DateTime from, DateTime anchor);  // from 이후 첫 발생일
  String toRRule(DateTime? until);                          // 캘린더용
  String encode();                                          // DB 저장
  static RecurrenceRule decode(String s);
}
```

- **anchor** = 마스터의 `dueAt`(반복 시작 기준일/시각). monthly 는 anchor의 day, yearly 는 anchor의 month+day 사용.
- **월말 보정**: 매월 31일 규칙인데 그 달에 31일이 없으면 그 달의 **마지막 날**로 클램프(예: 2월 28/29). RRULE 기본 동작과 일치시키되 앱 생성도 동일 규칙.

## 3. 인스턴스 생성 (materializer)

순수 함수로 설계해 테스트 용이하게 한다.

```dart
// 입력: 활성 마스터 목록 + 각 마스터의 기존 인스턴스 발생일 집합 + now
// 출력: 새로 만들 인스턴스 Todo 목록
List<Todo> materializeDue(List<Todo> masters, Map<String,Set<DateTime>> existingBySeries, DateTime now);
```

규칙:
1. 각 마스터에 대해 `anchor`(=master.dueAt)부터 시작, `nextOccurrence` 로 발생일을 순차 계산.
2. 발생일 ≤ **오늘 자정**(미래분 제외) 이고 `recurrenceEndAt` 이전인 것만 대상.
3. `(seriesId, 발생일)` 이 기존 인스턴스에 없으면 새 인스턴스 Todo 생성:
   - `id`=새 UUID, `seriesId`=master.id, `isSeriesMaster`=false
   - `dueAt`=발생일(+ master의 시각/`isAllDay`/`timeAnchor`/`endAt` 패턴 복제)
   - `title`/`category`/`description`/`type` = master에서 복제
   - `recurrenceRule`/`recurrenceEndAt` = null (인스턴스는 규칙 미보유)
   - `calendarEventId` = null (캘린더는 마스터가 소유)
4. 생성분은 기존 `todoRepository.upsert()` 경로로 저장 → outbox/Supabase 자동 동기화.

**idempotency**: 동기화로 다른 기기가 이미 만든 인스턴스가 들어올 수 있음. `(seriesId,발생일)` 중복 가드로 양쪽이 같은 날 인스턴스를 두 번 만들지 않음. (드물게 경합 발생 시 LWW + 중복 가드로 수렴; 잔여 중복은 dedup 표시가 흡수)

**트리거 지점**:
- 앱 시작 시 1회 (`watchTodayTodosProvider` 최초 빌드 또는 별도 init).
- `currentDayProvider` 자정 갱신 콜백에서 1회.
- (선택) 앱 포그라운드 복귀 시.

## 4. 가시성 / 이월 / dedup

### 4.1 VisibilityPolicy
- 마스터(`isSeriesMaster==true`)는 '오늘'·'전체보기'·카테고리 목록 **모두에서 제외**. 마스터는 "반복 관리" 진입점에서만 노출/편집.
- 인스턴스는 변경 없음 — 기존 `dueAt` 기준 노출 그대로.

### 4.2 CarryoverPolicy
- 변경 없음. 인스턴스가 일반 Todo로 흐르므로 미체크 이월 자동.

### 4.3 RecurrenceDedupPolicy (신규, FR-4)
오늘 목록 최종 빌드 단계에서 적용:
```dart
// 입력: VisibilityPolicy 통과한 오늘 목록
// 처리: 미체크 인스턴스를 seriesId 로 group → dueAt 가장 이른 1건만 leader 로 노출,
//        나머지 followers 는 숨기고 leader 에 hiddenCount 부착
// 체크된 인스턴스/일반 Todo 는 그대로 통과
```
- 반환 구조: `TodayItem { Todo leader; int hiddenCount; }` 형태로 UI에 전달(또는 leader Todo + 별도 count map).
- 사용자가 leader 를 체크하면 다음 follower 가 leader 로 승격(자연히 다음 빌드에서). UX: "○○ 외 N건" 배지.

## 5. 외부 인터페이스 — Google Calendar (FR-8)

- **마스터가 단일 RRULE 이벤트 소유**. 마스터 생성/규칙수정/삭제 시:
  - 생성: `buildEvent(master)` + `recurrence: [rule.toRRule(recurrenceEndAt)]` → eventId 를 master.calendarEventId 에 저장.
  - 수정: 규칙/제목/시간 변경 시 `updateEventForTodo`.
  - 삭제/해제: `deleteEvent`.
- 인스턴스는 캘린더 이벤트를 만들지 않음(RRULE 이 커버). 개별 인스턴스 체크는 캘린더에 영향 없음(범위 밖: 인스턴스 단위 예외).
- 시간 매핑은 기존 `TodoDateMode`(none/allDay/startTime/endTime/range) 로직 재사용.

## 6. 마이그레이션

### 6.1 Drift (로컬) v6 → v7
`app_database.dart` `schemaVersion = 7`, `onUpgrade` 에 idempotent ALTER 추가:
```dart
// PRAGMA 가드 후 없으면 추가 — 부분 적용 DB 안전
ALTER TABLE todos ADD COLUMN series_id TEXT;
ALTER TABLE todos ADD COLUMN recurrence_rule TEXT;
ALTER TABLE todos ADD COLUMN recurrence_end_at INTEGER;   // Drift DateTime
ALTER TABLE todos ADD COLUMN is_series_master INTEGER NOT NULL DEFAULT 0;
```

### 6.2 Supabase
`schema.sql` 갱신 + 마이그레이션 SQL:
```sql
alter table todos add column if not exists series_id text;
alter table todos add column if not exists recurrence_rule text;
alter table todos add column if not exists recurrence_end_at timestamptz;
alter table todos add column if not exists is_series_master boolean not null default false;
create index if not exists todos_series_idx on todos(user_id, series_id);
```
RLS 변경 불필요(기존 `auth.uid()=user_id` 그대로). Realtime publication 변경 불필요(컬럼 추가).

### 6.3 매핑
`supabase_todos_api.dart` `_toRow`/`_fromRow` 에 4개 필드 추가(snake_case ↔ camelCase, UTC 처리 동일).

## 7. 핵심 결정 (대안 비교)

| # | 결정 | 대안 | 채택 이유 |
|---|---|---|---|
| D1 | 마스터-인스턴스(실체화) | 가상 occurrence(표시용만, 미실체화) | 인스턴스를 실체 Todo로 두면 이월/체크/동기화/히스토리 전부 기존 로직 재사용. 가상 방식은 체크 상태·이월·동기화를 전부 새로 설계해야 함 |
| D2 | todos 컬럼 확장 | 별도 recurrence_rules 테이블 | sync/outbox/RLS 경로 재사용, 마이그레이션 단순 (§2.1) |
| D3 | lazy 생성(오늘까지만) | 미래분 선생성(N개월치) | DB 비대화 방지, "발생일에 등장" 의미와 일치, 규칙 수정 시 미래 인스턴스 정리 불필요 |
| D4 | dedup = 표시 레이어 | 데이터에서 누락분 병합/삭제 | PRD 결정(이력 보존 + 가시성). 데이터 무손실 |
| D5 | 캘린더 RRULE = 마스터 1이벤트 | 인스턴스마다 이벤트 | 캘린더 폭증 방지, RRULE 표준 활용 |

## 8. 예비 리스크

- **R1 (동기화 중복 생성)**: 두 기기가 같은 발생일 인스턴스를 동시 생성 → `(seriesId,발생일)` 중복 가드 + dedup 표시로 흡수. 잔여 시 정리 유틸 고려.
- **R2 (시간대/자정 경계)**: 발생일 계산은 로컬 자정 기준(`toLocal()`), 저장은 UTC. 기존 정책과 동일 규칙 유지.
- **R3 (월말/윤년)**: 매월 31일·매년 2/29 클램프 규칙(§2.2). 단위 테스트로 고정.
- **R4 (대량 누락 생성)**: 오래 안 켠 뒤 매일 반복이 수십 건 생성 → 이월+dedup으로 화면은 안전하나 DB row 증가. 생성 상한(예: 과거 N일까지만 채움) 고려.
- **R5 (마스터 노출 누락)**: 마스터를 모든 목록에서 빼면 사용자가 규칙을 못 찾음 → "반복 관리" 진입점 필수.

## 9. 테스트 전략

- **순수 함수 단위 테스트**: `RecurrenceRule.nextOccurrence`(4주기 × N간격 × 월말/윤년 경계), `toRRule`, `materializeDue`(idempotency·종료일·미래분 제외), `RecurrenceDedupPolicy`.
- **정책 통합**: 인스턴스 이월(Carryover) + dedup 동시 시나리오.
- **마이그레이션**: v6 DB → v7 ALTER 후 기존 데이터 보존 + 신규 컬럼 기본값.
- **캘린더**: `buildEvent` 가 마스터에 RRULE 문자열을 올바르게 싣는지(단위).

---
## 변경이력
<!-- change-history skill auto-appends entries here, oldest first -->
