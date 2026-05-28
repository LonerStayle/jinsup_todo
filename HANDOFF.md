# HANDOFF — 다음 세션 (ralph 자동 루프) 진입용

> 매 iter 시작 시 CLAUDE.md / PROMPT.md / IMPLEMENTATION_PLAN.md 와 함께 이 파일도 읽는다.
> 외부 환경 / 함정 / 우선순위는 여기에만 적혀 있다.
> 마지막 업데이트: **2026-05-28**

---

## 1. 현재 단계

**v1.0.0 후속 — § 10 보강** 진입.

- 9 phase / 45 task 모두 `[x]` 완료 (commit `087c761` 시점 PROJECT_DONE 출력)
- 그 후 사용자 실사용 + 코드 재검토로 **§ 10 (33 task) 추가** (commit `b96cecc`)
- main branch, working tree clean
- analyze clean / test 123/123 PASS / Android release APK 빌드 검증
- 디자인 9.1 / 편의성 9.4 (임계값 9 도달)

---

## 2. 외부 환경 상태 (사용자가 이미 셋업한 것)

| 항목 | 상태 |
|------|------|
| macOS Xcode 풀 설치 + `xcode-select --switch` + `xcodebuild -runFirstLaunch` | ✅ 완료 |
| CocoaPods (`brew install cocoapods`) | ✅ 완료 |
| `make setup` (pub get + pod install) | ✅ 완료 |
| Supabase 프로젝트 + schema `solo_todo` + `todos` 테이블 + RLS + index + publication | ✅ SQL 실행 완료 |
| Supabase **Exposed schemas** 에 `solo_todo` 추가 | ✅ 완료 |
| Supabase Email Templates (`Confirm signup` + `Magic Link`) 가 `{{ .Token }}` 표시 | ✅ 수정 완료 |
| `.env.local` (SUPABASE_URL / ANON / GOOGLE OAuth desktop + Android) | ✅ 채움 |
| Android debug SHA-1 | `F8:EC:9C:48:5D:79:DB:8B:D3:41:42:4C:65:33:14:EB:71:35:AE:DC` |

Supabase OTP length 는 8자리 (앱은 6~10 가변 허용으로 대응).

---

## 3. 다음 진행 우선순위 — § 10-A 부터

**§ 10-A (사용자 직접 보고 4 건)** 진행 현황:

1. ~~체크 풀림~~ ✅ **fix 됨** (commit `554c44e`) — realtime self-receive → outbox 재enqueue 무한 사이클 차단.
2. ~~삭제 불가~~ ✅ **fix 됨** (commit `554c44e`) — 동일 원인 통합 패치.
3. ~~무한 호출~~ ✅ **fix 됨** (commit `554c44e`) — 위 사이클이 가장 강력한 원인.
4. ~~dueAt 종일 옵션~~ ✅ **fix 됨** (commit pending) — `_pickDueDate` 가 date 만 받고 기본 종일. `_DueRow` 에 "시간 추가" / "시간 변경" / "하루 종일" 액션. `AddTodoSubmission.isAllDay` + `CalendarService` 종일 event 분기.

**fix 요지** (`lib/src/data/remote/supabase_realtime_sync.dart`):
- `localApply: TodoRepository` 가 **outbox 우회** repository (LocalTodoRepository) 여야 한다고 명시.
- `flushOutbox: Future<void> Function()` 별도 콜백으로 분리 — realtime sync 가 outbox 를 직접 알지 않음.
- `applyInsertOrUpdate` / `applyDelete` 메서드 분리 (`@visibleForTesting`).
- `forApplyOnly` 명명 생성자 추가 — 단위 테스트가 SupabaseClient mocking 없이 apply 동작만 검증.
- provider 에서 `LocalTodoRepository(db.todosDao)` 를 별도 생성해 주입.

테스트 (`test/src/data/remote/supabase_realtime_sync_test.dart`): 3 개 신규 케이스.
- self-receive 반복 broadcast → outbox count 0 유지 + local doneAt 유지
- delete self-receive → outbox 0 + local 삭제 유지
- stale updatedAt remote → LWW 가 local 채택 (체크 풀림 X)

총 126/126 PASS (이전 123 + 3).

**§ 10-A 모두 완료**. § 10-B 진행 중 (6/24 완료, 상태/동기화 영역 완료):
- ✅ `currentDayProvider` 자정 Timer race 가드 (commit `5075239`)
- ✅ `SyncingTodoRepository.flushPending` mutex + rerun coalesce (commit `99847e3`)
- ✅ LWW strict `>` (동률 시 local 채택) (commit `222465b`)
- ✅ Realtime self-receive stomp 가드 — 위 두 패치로 통합 해소
- ✅ `SupabaseRealtimeSync.start` 순서 재배치 — subscribe 먼저 (commit `e70652f`)
- ✅ signOut + user 변경 시 옛 데이터 cleanup (commit `4fcbcc8`)
- ✅ watchAll 의 doneAt 정렬에 `NullsOrder.first` 명시 (commit `f58a130`)
- ✅ AddTodoSheet 더블 submit 가드 — `_submitted` 플래그 (commit `66fa819`)
- ✅ 카테고리 chip selected outline 강조 (commit `a1735fe`)
- ✅ 이월 배너 다크 모드 가독성 — alpha 분기 (commit `5541a44`)
- ✅ Dismissible threshold 0.6 + confirmDismiss 옵션 노출 (commit `f2c2bfc`)
- ✅ FAB 위치 — mobile endContained / desktop endFloat (commit `2cf25c5`)
- ✅ `_ShortcutsHost` 0~5 키 TextField focus 가드 (commit `f9b8ad0`)
- ✅ AppShell desktop bottomNavigationBar:null 의도 주석 (commit `becd9d4`)

**§ 10-B UI 동작 8/8 완료**. § 10-B 에러 처리 진행 중 (1/4 완료):
- ✅ outbox count 기반 "동기화 대기" chip — HomeScreen 헤더 (commit `3e765ac`)
- ✅ Supabase auth 에러 분류 — rate limit / invalid email / OTP 만료 친화 메시지 (commit `61e218d`)
- ✅ Calendar 권한 거부 → AddTodoResult.calendarWarning + SnackBar (commit `a5dd0a4`)
- ✅ 토큰 만료/외부 sign-out 자동 cleanup (commit `7e6d78b`)

**§ 10-B 에러 처리 4/4 완료**. § 10-B 시스템/macOS 진행 중 (1/4):
- ✅ hotkey_manager unregisterAll → 우리 hotkey 만 unregister (commit `0876c22`)
- ✅ Tray icon 체크박스 SVG → 22/44/66 PNG 멀티 해상도 (commit `2fff903`)
- ✅ 시스템 단축키 비충돌 점검 + AppShell doc 명시 (commit pending)

다음: § 10-B 시스템 마지막 — tray menu "종료" 의 `SystemNavigator.pop()` 미저장 데이터 안전성 확인.

---

## 4. 핵심 파일 위치

```
CLAUDE.md                              비전 / 환경 (자동 로드)
PROMPT.md                              ralph 절차 (§1 매 iter 흐름)
IMPLEMENTATION_PLAN.md                 task 체크리스트 (§ 10 부터 진행)
AGENTS.md                              검증 명령 (dart analyze + format + flutter test)
Makefile                               make help / run / build / check / sql

lib/src/
├── app/                               SoloTodoApp + _AuthGate + Env
├── core/                              theme / platform / perf / date_format
├── domain/                            Category, Todo, policies (carryover/visibility)
├── data/
│   ├── local/                         AppDatabase (Drift) + TodosDao + OutboxDao + LocalTodoRepository
│   ├── remote/                        SupabaseTodosApi / Realtime / LWW / supabase_provider
│   ├── day_boundary_provider.dart     자정 Timer
│   ├── providers.dart                 appDatabase / todoRepository (Local or Syncing) / nowProvider
│   ├── syncing_todo_repository.dart   local + outbox + remote push 합성
│   └── todo_repository.dart           abstract interface
├── features/
│   ├── add_todo/                      AddTodoSheet + AddTodoController
│   ├── auth/                          AuthService (OTP) + SignInScreen + providers
│   ├── calendar/                      GoogleAuthService + CalendarService
│   ├── category/                      CategoryView + providers
│   ├── home/                          HomeScreen + today_providers (watchToday / carryoverCount / undoneCount)
│   ├── system/                        TrayService
│   └── todo_actions/                  toggle / delete / restore controller
└── ui/
    ├── app_shell.dart                 폼팩터 분기 + FAB + Cmd+N + 0~5 단축키
    ├── destination.dart
    └── widgets/                       TodoTile / DismissibleTodoTile / EmptyState / Skeleton / UndoSnackbar

supabase/
├── schema.sql                         신규 셋업 (idempotent)
└── migrate.sql                        옛 public 테이블 정리

assets/tray_icon.png                   22x22 placeholder
SETUP.html                             사용자용 가이드 (env + Supabase + OAuth + 빌드)
```

---

## 5. ralph 첫 iter 절차 (PROMPT.md §1 기반)

1. `git status` / `git log -5` 로 현재 확인
2. `IMPLEMENTATION_PLAN.md` 의 **§ 10 첫 `[ ]` task** 픽 (현재 § 10-A 의 첫 항목 = "체크 풀림 버그")
3. 작업 — 원인 추정 + 패치 + integration test 추가
4. `make check` (analyze + format + test) PASS 확인
5. commit + `[ ]` → `[x]` 토글
6. 종료 → Stop hook 재투입

---

## 6. 함정 / 주의사항

- **cwd 이슈**: Bash 호출이 종종 `mobile_ralph01` (옛 폴더명) 으로 reset 됨. **항상 절대경로** `/Users/goldenplanet/jinsup_ralph_mobile/solo_todo` 사용. 명령은 `cd /Users/.../solo_todo && ...` 로 시작.
- **Drift DateTime**: `storeDateTimeAsText: true` 적용 — ISO 8601 text 로 UTC/local 보존. SQL 비교 시 string 사전순.
- **Supabase 테이블 schema**: `solo_todo.todos` (public 아님). 코드는 `client.schema('solo_todo').from('todos')` 사용 중. SQL 작성 시도 `solo_todo.todos`.
- **LWW 동률 stomp**: `LastWriteWins.remoteWins` 의 `>=` 동일 시각 → 자기 자신 self-overwrite 가능 (§10-A 의 1+2 추정 원인).
- **인증**: 매직링크 채택 안 함. OTP 6~10 자리 흐름. Site URL 이 다른 앱과 공유 불가능한 제약 때문. AuthService.sendEmailOtp + verifyEmailOtp(type: OtpType.email).
- **Widget test 에서 Drift stream 직접 사용 금지**: pending timer leak 으로 binding._verifyInvariants 위반. `StreamController` override 패턴 사용 (참고: `test/src/features/home/cleanup_trigger_test.dart`).
- **fake_async + ProviderContainer**: `nowProvider.overrideWithValue(() => clock.now())` 패턴 (참고: `day_boundary_provider_test.dart`).
- **NavigationBar 6 destinations**: Android 폰 좁은 화면에서 빡빡. 디자인 보강 후보.
- **macOS desktop 의 bottomNavigationBar**: null 분기. 의도된 것.
- **TestWidgets timer 누수**: AnimationController (TodoListSkeleton 등) 가 매 frame vsync. 화면 unmount 시 정상 dispose 됨.

---

## 7. 빌드 / 검증 (Makefile)

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

## 8. 이 인수인계서 갱신 규칙

- § 10 항목 진행 / 결함 추가 발견 시 → § 3 (우선순위) 와 IMPLEMENTATION_PLAN.md 동시 갱신
- 외부 환경 (Supabase 셋업 / Xcode / env) 상태 변경 시 → § 2 갱신
- 새 함정 발견 시 → § 6 갱신
- 큰 결정 변경 (LWW 정책 변경 등) 시 → § 3 의 근거 섹션 갱신

ralph 가 다음 iter 들에서 § 10 진행하며 매 commit 마다 이 파일도 같이 업데이트.
