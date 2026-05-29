# HANDOFF — 다음 세션 (fresh context) 진입용

> ralph 자동 루프 + 사람 reader 모두 이 파일 하나로 컨텍스트 복원 가능하게 작성.
> 매 iter 시작 시 CLAUDE.md / PROMPT.md / IMPLEMENTATION_PLAN.md 와 함께 이 파일도 읽는다.
> 마지막 업데이트: **2026-05-29**

---

## 0. Goal (현재 무엇을 만들고 있나)

**Solo Todo** — 대표님(30대 개발자, 1인 사용) 전용 macOS desktop + Android 통합 Todo 앱.

- **Flutter (Dart)** 단일 코드베이스, **Supabase** 백엔드 (Auth + Postgres + RLS + Realtime), **Google Calendar API** 연동.
- 비전: 메모장 대체. UI 가독성 최강 + UX 단축 동작 강력. v1.0.0 한 번에 완성품.
- 자가평가 기준: 디자인 점수 + 편의성 점수 모두 9/10 이상.

세부 비전은 `CLAUDE.md` 의 "비전 / 사양" 8 섹션 참조.

---

## 1. Current Progress (어디까지 왔나)

### 완료 단계

| 단계 | 상태 | 메모 |
|------|------|------|
| **v1.0.0 — 9 phase / 45 task** | ✅ 종료 (`087c761`) | 첫 PROJECT_DONE |
| **§ 10 — 사용자 실사용 보고 + 코드 재검토 보강 (33 task)** | ✅ 종료 (`e16bd68`) | 디자인 9.3 / 편의성 9.5 |
| **§ 11 — v1.1 폴더/Outline 트리/bulk paste/메모 타입 (16 task)** | ✅ 종료 (`13b895a`) | 디자인 9.4 / 편의성 9.6 |
| **§ 12 — v1.2 카테고리 fully 동적 + Todo description (25 ralph task)** | ✅ 종료 (`d3c8509`) | 디자인 9.4 / 편의성 9.6. 대표님 직접 task 1개 남음 (CLAUDE.md § 3) |

### 현 상태 (2026-05-29)

- main branch, working tree (SETUP/HANDOFF/PLAN 갱신 중)
- analyze clean / format clean / **flutter test 326/326 PASS**
- v1.1 → v1.2 backwards-compat (Drift onUpgrade 2→3 + Supabase ALTER IF NOT EXISTS + Category JsonKey converter + description nullable)
- SETUP.html § 2 끝에 v1.1→v1.2 마이그레이션 안내 (categories CREATE + todos.description ALTER) 추가

### ✅ 대표님 직접 작업 — 완료

**CLAUDE.md 비전 § 3** 의 "카테고리 분류 — 5종 고정" → "기본 5종 + 사용자 자유롭게 추가/삭제 가능 (v1.2~), 안 todos 남으면 삭제 차단" 으로 갱신 완료 (대표님 명시 지시). 비전-구현 일관성 회복 — § 12 v1.2 **완전 종료**.

### v1.2 완료 기능 (참고)

- **카테고리 fully 동적**: enum → freezed data class + Drift/Supabase categories 테이블. sidebar "카테고리 추가" (label+16색+12아이콘) / long-press·우클릭 삭제. builtin 도 삭제 가능 (안 todos ≥1 이면 차단).
- **동적 단축키**: today=0 / 카테고리 1~9 / outline N+1 (N<9). 9 초과는 tap.
- **Todo description**: AddTodoSheet "상세 메모" 토글 + multi-line. TodoTile 힌트 아이콘.
- **Todo 편집**: TodoTile tap → AddTodoSheet edit 모드 (initialTodo prefill + onUpdate → TodoActions.update). HomeScreen / CategoryView 연결 (OutlineScreen tap-edit 은 v1.3).

### v1.1 완료 기능 (참고)

- **트리 구조**: todo 에 parent_id 추가, 무한 깊이 자식 가능 (메모장 사례 → 앱 그대로 매핑)
- **메모(note) 타입**: type='task' / 'note'. note 는 체크 X, today 화면 제외, 진척률 분모 제외
- **Outline view**: 단축키 6. 5 카테고리 root + 자식 트리 펼침/접힘 + [N/M] progress bar
- **Bulk paste**: AddTodoSheet 의 multi-line paste → N개 todos 일괄 추가 (confirm dialog)
- **Today breadcrumb**: today list 의 각 todo 옆에 "JS슈퍼 / 울트라 모드" 식 path

---

## 2. 외부 환경 상태 (대표님이 이미 셋업한 것)

| 항목 | 상태 |
|------|------|
| macOS Xcode 풀 설치 + `xcode-select --switch` + `xcodebuild -runFirstLaunch` | ✅ |
| CocoaPods (`brew install cocoapods`) | ✅ |
| `make setup` (pub get + pod install) | ✅ |
| Supabase 프로젝트 + schema `solo_todo` + `todos` 테이블 + RLS + index + publication | ✅ SQL 실행 완료 |
| Supabase **Exposed schemas** 에 `solo_todo` 추가 | ✅ |
| Supabase Email Templates (`Confirm signup` + `Magic Link`) 가 `{{ .Token }}` 표시 | ✅ |
| `.env.local` (SUPABASE_URL / ANON / GOOGLE OAuth desktop + Android) | ✅ |
| Android debug SHA-1 | `F8:EC:9C:48:5D:79:DB:8B:D3:41:42:4C:65:33:14:EB:71:35:AE:DC` |
| Supabase OTP length | 8자리 (앱은 6~10 가변 허용) |
| **v1.1 ALTER (parent_id / type / sort_order)** | ⚠️ **확인 필요** — SETUP.html § 2 끝 |

---

## 3. Next Steps — v1.2 진행

### 3-A. 대표님 직접 작업 (ralph 못 함)

1. **CLAUDE.md 비전 § 3 갱신** — "카테고리 분류 — 5종 고정" 표현을 "기본 5종 + 사용자 추가/삭제 가능" 으로 변경. vision-intake skill 영역이라 ralph 가 수정 X. **이거 안 하면 v1.2 plan 과 비전이 모순** — ralph 가 § 5 (금지) 와 헷갈릴 수 있음.

### 3-B. ralph 자동 작업 (26 task)

IMPLEMENTATION_PLAN.md 의 `### 12. v1.2 — 카테고리 fully 동적 + Todo 상세 메모` 섹션. 의존성 순서:

| 그룹 | task 수 | 핵심 |
|------|---------|------|
| 비전 영역 | 1 | (대표님 직접 — ralph 건너뜀) |
| Category 도메인 모델 | 1 | enum → freezed data class + builtinSeeds |
| Drift schema + DAO + migration | 4 | categories 테이블 신규 + schemaVersion 2→3 + migration test + CategoriesDao |
| 카테고리 정책 + Controller | 2 | CategoryDeletePolicy (안 todos ≥1 차단) + CategoriesController |
| Supabase 동기화 | 3 | schema.sql + SupabaseCategoriesApi + SyncingCategoriesRepository |
| 카테고리 UI | 4 | sidebar dynamic destination + 단축키 1~9 + ADD dialog + DELETE + widget test |
| Todo description | 4 | 모델/Drift/Supabase/schema.sql |
| Edit todo | 5 | AddTodoSheet description + initialTodo edit 모드 + TodoActions.update + TodoTile.onTap + 힌트 아이콘 |
| 테스트 통합 | 2 | edit 모드 widget test + 단축키 동적 매핑 widget test |

### 3-C. ralph-loop 재시작

```bash
/ralph-loop:ralph-loop "Read PROMPT.md and follow it." --completion-promise "PROJECT_DONE" --max-iterations 34
```
(권장 34 = 26 × 1.3, 검증 재시도 여유)

---

## 4. What Worked (반복할 만한 접근)

- **bite-sized commit** — 한 iteration = 한 task = 1~3 파일 수정 + 단위 테스트. 분해가 곱고 의존성 순서 (DB → Domain → UI → 테스트) 일관.
- **backwards-compat 패턴** — Drift onUpgrade case 별 ALTER + Supabase `ALTER TABLE ADD COLUMN IF NOT EXISTS` 안내 주석 + JSON `@Default` 로 옛 payload 안전 복원.
- **stream provider override 로 widget test** — Drift in-memory DB 는 timer leak 위험. `StreamProvider.overrideWith((_) => Stream.value([]))` 패턴 (`HANDOFF.md § 6` 함정).
- **pure 함수 분리** — `splitBulkLines`, `computeTodoPath`, `computeSubtreeProgress` 처럼 도메인 로직을 `@visibleForTesting` static 으로 노출. unit test 가 widget mount 없이 직접 검증.
- **fake_async + clock + nowProvider** — 자정 trigger, debounce 등 시간 의존 로직을 결정적으로 검증.
- **race 가드 패턴** — `_submitted` flag / mutex (`_flushing` + `_rerunRequested`) / Timer cancel 후 재설정 (debounce).

---

## 5. What Didn't Work (반복하지 말 것)

- **Widget test 에서 Drift stream 직접 사용** — pending timer leak 으로 `binding._verifyInvariants` 위반. 반드시 stream provider override 패턴.
- **AppShell widget mount 통합 테스트** — hotkey_manager / tray / Timer 의 dispose 가 까다로워 hang. controller + DB 레벨 통합으로 검증 (`app_shell_flow_test.dart` 참고).
- **LWW 동률 stomp** — `>=` 동일 시각 → self-overwrite. `>` strict (§ 10-A 4건 통합 fix 의 핵심 원인).
- **TextField maxLines: 1 + paste 감지** — `\n` 자동 제거되어 multi-line paste 감지 불가. `maxLines: 5 + keyboardType.multiline + onChanged \n 감지` 패턴.
- **Riverpod 3 의 valueOrNull** — 일부 버전에서 미존재. `.asData?.value` 사용.

---

## 6. 함정 / 주의사항

- **cwd**: Bash 호출이 종종 옛 폴더로 reset. **항상 절대경로** `/Users/goldenplanet/jinsup_ralph_mobile/solo_todo` 사용.
- **Drift DateTime**: `storeDateTimeAsText: true` — ISO 8601 text 로 저장. SQL 비교 시 string 사전순.
- **Supabase schema**: `solo_todo.todos` (public 아님). 코드는 `client.schema('solo_todo').from('todos')`. SQL 도 `solo_todo.*`.
- **LWW**: 동률 stomp 회피 위해 `>` strict (>=) X.
- **인증**: 매직링크 X / OTP 6~10 자리 (Site URL 공유 불가 제약). `AuthService.sendEmailOtp` + `verifyEmailOtp(type: OtpType.email)`.
- **Widget test ↔ Drift stream**: provider override 필수.
- **fake_async**: `nowProvider.overrideWithValue(() => clock.now())` 패턴.
- **NavigationBar 6 destinations**: Android 폰 좁은 화면 빡빡. **v1.2 에서 N 동적이 되면 더 빡빡** — UI 보강 필요할 수도.
- **macOS desktop bottomNavigationBar**: null 분기 의도.
- **TestWidgets timer 누수**: AnimationController 가 vsync, 화면 unmount 시 정상 dispose.
- **Riverpod 3**: `valueOrNull` → `.asData?.value`.
- **Widget mount viewport**: AddTodoSheet 가 길어져 `setSurfaceSize(400, 1400)` 필요. `_Actions row` 가 viewport 밖이면 tap 무시 — `onPressed` 직접 호출 패턴이 안전.

---

## 7. 핵심 파일 위치 (v1.1 종료 시점)

```
CLAUDE.md                              비전 / 환경 (자동 로드) — § 3 갱신 필요!
PROMPT.md                              ralph 절차 (§1 매 iter 흐름)
IMPLEMENTATION_PLAN.md                 task 체크리스트 (§ 12 v1.2 진입 직전)
AGENTS.md                              검증 명령 (dart analyze + format + flutter test)
Makefile                               make help / run / build / check / sql

lib/src/
├── app/                               SoloTodoApp + _AuthGate + Env
├── core/                              theme / platform / perf / date_format
├── domain/
│   ├── category.dart                  ⚠️ v1.2 에서 enum → freezed data class
│   ├── todo.dart                      Todo + TodoType (task/note) + parentId/sortOrder
│   └── policies/
│       ├── carryover_policy.dart      note 분리 적용됨
│       └── visibility_policy.dart     note 분리 적용됨
├── data/
│   ├── local/                         AppDatabase (schemaVersion 2) + TodosDao + OutboxDao + LocalTodoRepository
│   ├── remote/                        SupabaseTodosApi / Realtime / LWW / supabase_provider
│   ├── day_boundary_provider.dart     자정 Timer
│   ├── providers.dart                 appDatabase / todoRepository / nowProvider / outboxCountProvider
│   ├── syncing_todo_repository.dart   local + outbox + remote push 합성
│   └── todo_repository.dart           abstract interface
├── features/
│   ├── add_todo/                      AddTodoSheet (task/note + bulk paste) + AddTodoController
│   ├── auth/                          AuthService (OTP + 300ms debounce) + SignInScreen + providers
│   ├── calendar/                      GoogleAuthService + CalendarService
│   ├── category/                      CategoryView + providers
│   ├── home/                          HomeScreen (breadcrumb) + today_providers
│   ├── outline/                       ⭐ v1.1 신규 — OutlineScreen + tree_providers (allTodos / childrenOf / rootsOfCategory / SubtreeProgress / computeTodoPath)
│   ├── system/                        TrayService
│   └── todo_actions/                  toggle / delete / restore controller (v1.2 에 update 추가 예정)
└── ui/
    ├── app_shell.dart                 폼팩터 분기 + FAB + Cmd+N + 0~6 단축키 (SidebarItem public)
    ├── destination.dart               DestinationKind enum (today/category/outline)
    └── widgets/
        ├── animated_todo_list.dart    AnimatedTodoSliver (SliverAnimatedList + id-diff + breadcrumbBuilder)
        ├── dismissible_todo_tile.dart Dismissible + TodoTile (threshold 0.6)
        ├── todo_tile.dart             note → sticky_note 아이콘 + italic
        ├── empty_state.dart
        ├── skeleton.dart              TodoListSkeleton
        └── undo_snackbar.dart         _UndoContent + progress bar

supabase/
├── schema.sql                         v1.1 ALTER 안내 포함 (parent_id/type/sort_order)
└── migrate.sql                        옛 public 테이블 정리

assets/tray_icon.png                   22/44/66 PNG 멀티 해상도
SETUP.html                             사용자용 가이드 (v1.0 + v1.1 마이그레이션)
docs/audit/                            /audit-risk 1회성 산출물 (gitignored)
```

---

## 8. 빌드 / 검증 (Makefile)

```bash
make check        # analyze + format-check + test (커밋 직전)
make run          # macOS 데스크탑 실행
make run-android  # Android 첫 device 자동 선택
make build-apk    # release .apk
make codegen      # freezed / json / drift codegen
make sql          # schema.sql 클립보드 (Supabase SQL Editor 붙여넣기용)
```

`.env.local` 자동 감지 — 있으면 `--dart-define-from-file` 자동 주입.

---

## 9. 이 HANDOFF 갱신 규칙

- task 진행 / 외부 환경 변경 시 § 1 / § 2 동기화
- 새 함정 발견 시 § 6 추가
- v1.x 종료 시 § 1 의 단계 표 + § 7 핵심 파일 위치 갱신

ralph 가 v1.2 진행 중 매 commit 마다 이 파일도 함께 갱신.
