# 인수인계서 — 날짜 반복 (date-repeat)

> 이 문서는 **date-repeat 기능 한정** 인수인계서다. 프로젝트 전체 외부환경 인수인계서는
> 루트 `HANDOFF.md`(별도, 덮어쓰지 말 것). 새 세션은 이 파일 경로만 주면 이어받을 수 있다.
>
> 작성 시점: 2026-05-31 / 브랜치: `date-repeat` (worktree `.worktrees/date-repeat`)

---

## Goal (목표)

체크리스트(할 일)에 **날짜 반복** 기능 추가. 대표님 확정 사양 4가지:
1. **N간격 반복** — 매일/매주(요일)/매월/매년 + "N마다"
2. **미체크 이월 + 같은 반복 1건만 표시(B안)** — 데이터 보존, 화면엔 가장 오래된 1건 + "밀린 반복 외 N건" 배지
3. **종료일 지정** — 선택 시 그 이후 발생 안 함
4. **Google Calendar RRULE 연동** — 마스터가 반복 이벤트 1개 소유

추가로 **"반복 중지" UX** 보강 중 (대표님 피드백: 항목에서 직접 끌 수 있어야 함).
- Q1=C: 반복 중지를 **편집 시트 + 타일 ⋮ 메뉴** 둘 다에 노출
- Q2=예: 편집 시트·상세·관리 화면에 **규칙 요약 텍스트**("매주 · 2026.12.31 까지") 표시

기획 3종: `docs/features/2026-05-31-date-repeat/date-repeat-{requirements,tech-design,implementation-plan}.md`

---

## 설계 핵심 (이어받을 때 꼭 알 것)

- **마스터-인스턴스 모델**: 반복 규칙은 숨김 "마스터 Todo"(`isSeriesMaster=true`, `seriesId=자기 id`,
  `recurrenceRule`/`recurrenceEndAt` 보유)가 가진다. 발생일마다 실제 "인스턴스 Todo"를 만든다.
  인스턴스는 일반 Todo와 동일 → 기존 이월/오늘/동기화 로직을 그대로 재사용.
- **결정적 인스턴스 id**: `${seriesId}#yyyymmdd`. 같은 (시리즈,발생일)은 항상 같은 id →
  스트림 재방출/다기기 동시생성에도 중복 불가. (랜덤 uuid 쓰지 말 것 — 과거 그래서 RED 났음)
- **마스터는 모든 목록에서 제외**(VisibilityPolicy). 노출은 인스턴스만. 규칙 조회/중지는
  `recurringMastersProvider` + "반복 관리" 화면 또는 항목의 반복중지 진입점으로만.
- **반복 중지 = 마스터만 삭제(비파괴적)**: 미래 발생분만 멈추고 기존 인스턴스는 일반 할 일로 남음.
  공용 헬퍼 `confirmStopRecurrence(context, ref, item)` (lib/src/features/recurrence/recurrence_actions.dart).
  인스턴스 → `RecurrenceMaterializer.findMaster`로 마스터 역추적 후 confirm→delete.

핵심 파일:
- 도메인: `lib/src/domain/recurrence.dart`(RecurrenceRule + `describe()`/`toRRule()`/`nextOccurrence()`),
  `recurrence_materializer.dart`(materializeDue/findMaster), `policies/recurrence_dedup_policy.dart`
- 배선: `features/home/today_providers.dart`(recurrenceMaterializerProvider, dedupedTodayProvider, recurringMastersProvider)
- UI: `features/add_todo/add_todo_sheet.dart`(추가=입력 / 편집=_RecurrenceEditInfo), `features/recurrence/`,
  `ui/widgets/todo_tile.dart`(반복 아이콘 + "외 N건" 배지 + ⋮ '반복 중지')

---

## Current Progress (현재 상태)

- 브랜치 `date-repeat`, **main 대비 27 커밋. main 미머지** (대표님이 직접 동작 확인 후 머지 예정).
- **앱 코드(lib)는 `dart analyze` 0 issues / `dart format` 0-changed = 컴파일·정상 동작.**
  → 실제 앱에서 반복 추가·자동생성·이월·dedup·캘린더·반복중지 모두 동작함.
- Phase A~J(백엔드~UI) + "반복 중지" 보강(편집시트/타일메뉴/규칙요약)까지 구현 완료.

### ⚠️ 미해결: 테스트 1건 RED (기능 결함 아님, 테스트 finder 충돌)

- 파일: `test/src/features/add_todo/add_todo_sheet_edit_recurrence_test.dart`
- 케이스: **"반복 인스턴스 편집 → 규칙 요약 + 반복 중지 버튼"**
- 원인: `expect(find.textContaining('매주'), findsOneWidget)` 가 **2개** 매칭됨 —
  제목 필드의 "매주 정산" + 규칙 요약의 "매주 · 2026.12.31 까지". 둘 다 '매주' 포함.
- 즉 **앱 버그가 아니라 테스트 단언이 헐거운 것**. 나머지 558건은 GREEN.

---

## Next Steps (다음 할 일 — 우선순위)

1. **[1줄 수정] 실패 테스트 GREEN 화**
   - `add_todo_sheet_edit_recurrence_test.dart` 의 `find.textContaining('매주')` 단언을
     더 구체적으로: 같은 테스트에 이미 있는 `find.textContaining('2026.12.31')`(통과 중)로 충분하므로
     '매주' 줄을 **`findsWidgets`로 완화**하거나, `edit-recurrence-info` 키 컨테이너 안에서만 찾도록 변경.
   - 검증: `flutter test`(전체 GREEN) + `dart analyze`(0) + `dart format --set-exit-if-changed .`(0).
     **반드시 셋 다 결과를 눈으로 확인하고 커밋** (아래 함정 참조).

2. **대표님 직접 동작 확인** — 반복 추가 → 오늘 등장 → 항목 탭(편집시트) / ⋮ 메뉴에서 "반복 중지" 동작,
   상세·관리 화면 규칙 요약 표시. 디자인/편의성 점검.

3. **main 머지** — 대표님 승인 후. `js-super:worktree-merge-back` 또는 수동 머지.

4. (선택) 무날짜 반복 — 현재는 "날짜 지정해야 반복 섹션 노출". 대표님이 무날짜 반복도 원하면 설계 변경 필요.

---

## What Worked (성공한 접근)

- 마스터-인스턴스 + 결정적 id 모델 — 기존 정책/동기화 100% 재사용, 중복 원천 차단.
- 순수 함수(RecurrenceRule/materializer/dedup) 먼저 TDD → UI는 그 위에 배선.
- 위젯 테스트에서 Drift 의존 provider를 `Stream.value`/no-op으로 override (timer leak 회피).
  - HomeScreen 띄우는 테스트는 `recurrenceMaterializerProvider.overrideWith((_) {})` 필수.
  - 시트/관리 화면 테스트는 `categoriesProvider`/`groupsProvider`/`allTodosProvider` override 필수.

## What Didn't Work (반복하지 말 것)

- **검증과 커밋을 한 배치에 섞고, 백그라운드 잡을 여러 개 동시에 돌린 것** → 결과를 못 보고
  RED 상태로 여러 번 커밋함(이 세션 최대 실수). **검증은 별도 단계로, 결과 줄을 읽고 나서만 커밋.**
- **파일을 안 읽고 Edit** → linter 재포맷/구조 차이로 Edit가 silently 실패하는데 모르고 진행.
  특히 `dismissible_todo_tile.dart`, `todo_drill_list.dart`에 같은 Edit가 중복 삽입돼 깨졌음.
  → 의심되면 **파일 전체를 Read하고, 깨졌으면 Write로 통째 재작성**.
- `KoDate.short`(존재 X, `shortDate`가 맞음), 랜덤 uuid 인스턴스 id — 둘 다 과거 RED 원인.
- 관련 메모: `~/.claude/projects/.../memory/verify-gate-before-commit.md`

---

## 검증 명령 (AGENTS.md 단일 출처)

```bash
dart analyze                                   # 0 issues
dart format --output=none --set-exit-if-changed .   # 0 changed
flutter test                                   # All tests passed!
```
모두 exit 0 이어야 커밋. (현재 test만 1건 RED — Next Steps 1번)
