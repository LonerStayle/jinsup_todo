# 구현 계획: 할 일 날짜 반복 (date-repeat)

> 상위: `date-repeat-requirements.md` (PRD) + `date-repeat-tech-design.md`. 단계별 bite-sized TDD.
> 검증(매 단계 commit 직전): `dart analyze` / `dart format --output=none --set-exit-if-changed .` / `flutter test` 모두 exit 0.
> 코드젠: 모델/DB 변경 후 `dart run build_runner build --delete-conflicting-outputs`.

## 단계

### Phase A — RecurrenceRule 값객체 (순수, TDD) ✅선행
- [ ] A1. `lib/src/domain/recurrence.dart`: `RecurrenceFreq` enum + `RecurrenceRule`(freq/interval/byWeekday) + `encode/decode` + `toRRule(until)` + `nextOccurrence(from, anchor)`.
- [ ] A2. `test/domain/recurrence_test.dart`: 4주기 × N간격, 월말/윤년 클램프, byWeekday(weekly), encode↔decode 왕복, toRRule 문자열, nextOccurrence 경계.

### Phase B — Todo 모델 확장 (freezed + codegen)
- [ ] B1. `todo.dart`: 필드 `seriesId`/`recurrenceRule`(직렬화 String)/`recurrenceEndAt`/`isSeriesMaster` 추가 + `Todo.create` 파라미터 + 헬퍼(`isRecurringMaster` getter, `recurrence` 파싱 getter).
- [ ] B2. build_runner 코드젠. 기존 todo 테스트 통과 확인.

### Phase C — Drift 로컬 스키마 v7 (codegen + migration)
- [ ] C1. `app_database.dart`: Todos 테이블 컬럼 4개 + `schemaVersion=7` + `from<7` PRAGMA 가드 ALTER(idempotent).
- [ ] C2. `todos_dao.dart`: row↔domain 매핑에 신규 4필드.
- [ ] C3. build_runner 코드젠. 마이그레이션 테스트(v6→v7 데이터 보존 + 기본값).

### Phase D — Supabase 원격 스키마 + 매핑
- [ ] D1. `supabase/schema.sql`: todos 컬럼 4개 `add column if not exists` + series 인덱스.
- [ ] D2. 마이그레이션 SQL 파일(`supabase/migrations/` 또는 schema 주석) 정리.
- [ ] D3. `supabase_todos_api.dart` `_toRow`/`_fromRow`: 신규 4필드(snake_case, UTC).

### Phase E — materializer (순수, TDD)
- [ ] E1. `lib/src/domain/recurrence_materializer.dart`: `materializeDue(masters, existingBySeries, now)` 순수 함수.
- [ ] E2. `test/domain/recurrence_materializer_test.dart`: idempotency, 종료일 컷, 미래분 제외, 과거 누락 채움, 시각/allDay 패턴 복제.

### Phase F — 정책 (가시성 제외 + dedup)
- [ ] F1. `visibility_policy.dart`: `isSeriesMaster` 면 false(모든 목록 제외). 테스트 보강.
- [ ] F2. `recurrence_dedup_policy.dart` 신규 + 테스트: 같은 seriesId 미체크 → 가장 이른 1건 leader + hiddenCount.

### Phase G — 트리거 배선
- [ ] G1. `today_providers.dart` / `day_boundary_provider.dart`: 앱시작·자정에 materialize 호출(repo upsert) + 오늘 목록에 dedup 적용. 카테고리/전체보기에서 마스터 제외 확인.
- [ ] G2. 통합 테스트: 발생→이월→dedup 시나리오.

### Phase H — Google Calendar RRULE
- [ ] H1. `calendar_service.dart` `buildEvent`: 마스터면 `recurrence: [rule.toRRule(endAt)]`. 인스턴스는 이벤트 생성 안 함.
- [ ] H2. 단위 테스트(buildEvent RRULE 탑재).

### Phase I — UI
- [ ] I1. add/edit 시트: 반복 규칙 선택(주기·간격·요일·종료일). 마스터 생성 경로.
- [ ] I2. 오늘 아이템: 반복 아이콘(FR-7) + "외 N건" 배지(FR-4). "반복 관리" 진입점(마스터 목록/해제).
- [ ] I3. 위젯 테스트.

### Phase J — 마무리
- [ ] J1. 전체 검증 3종 exit 0 + 디자인/편의성 자가평가.

---
## 진행 현황 (2026-05-31)

**완료·커밋 (전체 테스트 539건 통과, analyze/format 클린):**
- [x] Phase A — RecurrenceRule 값객체 + 테스트
- [x] Phase B — Todo 모델 반복 4필드 (freezed)
- [x] Phase C — Drift v7 스키마 + v6→v7 마이그레이션 + DAO 매핑
- [x] Phase D — Supabase schema.sql ALTER 섹션 + 마이그레이션 + _toRow/_fromRow
- [x] Phase E — materializer (결정적 id `seriesId#yyyymmdd` → 중복 원천 차단)
- [x] Phase F — VisibilityPolicy/CarryoverPolicy 마스터 제외 + RecurrenceDedupPolicy
- [x] Phase G — recurrenceMaterializerProvider(앱시작·자정 트리거) + dedupedTodayProvider
- [x] Phase H — buildEvent RRULE 부착 (마스터 한정, UNTIL UTC)

**UI (Phase I) — 완료·커밋:**
- [x] **Phase I-a** — AddTodoSubmission.recurrence/recurrenceEndAt + AddTodoController
  가 마스터 저장 + anchor~오늘 인스턴스 즉시 실체화 (컨트롤러 테스트 3건).
- [x] **Phase I-b** — 추가 시트 반복 입력 UI (주기 칩·N간격 스텝퍼·요일 칩·종료일).
  편집 모드 미노출(규칙 수정은 별도 동작). 위젯 테스트 6건.
- [x] **Phase I-c** — TodoTile 반복 아이콘(FR-7) + "밀린 반복 외 N건" 배지(FR-4),
  HomeScreen materializer 활성화 + dedup 적용 + hiddenCountBySeries 배선,
  RecurrenceManageScreen(반복 중지=비파괴적) + 헤더 진입 버튼(FR-6). 테스트 추가.

### Phase J — 마무리 (완료)
- [x] J1. 전체 검증 3종 exit 0 (analyze 0 / format clean / test 551건 GREEN).

**자가평가 (CLAUDE.md §4):**
- 디자인 9.3 — 반복 아이콘·묶음 배지·관리 화면이 기존 톤(카테고리색·칩·카드)과 일관.
  고빈도 반복 누적 시 화면 도배를 dedup 으로 차단해 가시성 보호(앱 1순위 기준 충족).
- 편의성 9.4 — 날짜 지정 시 한 시트에서 주기·간격·요일·종료일까지 토글로 완결,
  발생일마다 자동 생성·이월, 캘린더 RRULE 1이벤트 자동 등록. 수동 재생성 부담 제거.

**구현 요약:** 마스터-인스턴스 모델로 기존 이월/오늘/동기화 로직 100% 재사용.
결정적 id(`seriesId#yyyymmdd`)로 다기기·재방출 중복 원천 차단. 백엔드~UI 14+커밋,
전 구간 TDD. v1.0 비전의 반복 기능 항목 충족.

---
## 변경이력
<!-- change-history skill auto-appends entries here, oldest first -->
