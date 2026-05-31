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
## 변경이력
<!-- change-history skill auto-appends entries here, oldest first -->
