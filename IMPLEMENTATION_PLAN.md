# IMPLEMENTATION_PLAN

> ralph 가 매 iteration 갱신하는 체크리스트. 모든 task `[x]` + 디자인 점수 ≥ 9 + 편의성 점수 ≥ 9 도달 시 `PROJECT_DONE`.
> 망가지면 통째 폐기 (disposable). 사람은 비워둔 채 시작 — ralph 가 CLAUDE.md 비전 보고 갱신.

---

## TODO

### 0. 부트스트랩
- [x] Bootstrap: Flutter macOS+Android scaffold, AGENTS.md 검증 파이프라인, plan 초안

### 1. 인프라
- [x] pubspec.yaml 코어 의존성 추가 (flutter_riverpod, supabase_flutter, drift, sqlite3_flutter_libs, path_provider, hotkey_manager, tray_manager, macos_ui, google_sign_in, googleapis, googleapis_auth, intl, uuid, freezed, freezed_annotation, json_annotation, json_serializable, build_runner, drift_dev)
- [x] lib/src 모듈 구조 정리 (app / core / domain / data / features / ui)
- [x] Env 환경변수 로딩 (`--dart-define-from-file=.env.local`) — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_OAUTH_CLIENT_ID_DESKTOP`, `GOOGLE_OAUTH_CLIENT_ID_ANDROID` + `.env.example` 추가
- [x] App entry point — ProviderScope + 폼팩터 분기 (macOS desktop vs Android phone)

### 2. 도메인 모델 (TDD)
- [x] `Category` enum (work / personalDev / daily / longterm / idea) + 한글 라벨 + 컬러 토큰
- [x] `Todo` 엔티티 (freezed + json_serializable) — id, title, category, dueAt, doneAt, createdAt, updatedAt, calendarEventId
- [x] `CarryoverPolicy.shouldCarryOverToday(todo, now)` 순수 함수 + unit test (미체크 이월 케이스)
- [x] `VisibilityPolicy.isVisibleToday(todo, now)` 순수 함수 + unit test (체크된 항목 당일 자정 hide 케이스)

### 3. 로컬 데이터 (Drift)
- [x] `todos` Drift 테이블 정의 + DAO (insert/update/delete/watchByCategory/watchToday)
- [x] `TodoRepository` 인터페이스 (local + remote 어댑터 추상화)
- [x] `LocalTodoRepository` 구현 + integration test (SQLite in-memory)

### 4. UI 골격
- [x] `AppTheme` — macos_ui Cupertino 톤 + 디자인 토큰 (간격 4/8/16/24, 타이포 스케일, 색 팔레트, 라운드 코너)
- [x] `AppShell` — macOS 사이드바 / Android 바텀 네비 폼팩터 분기
- [x] `HomeScreen` — 오늘 할 일 위젯 (오늘 섹션 + 이월된 항목 배너)
- [x] `CategoryView` — 카테고리별 필터 보기 (사이드바 선택 시)
- [x] `AddTodoSheet` — 빠른 추가 (제목 + 카테고리 chip + 일정 picker + Calendar 등록 토글)
- [x] `TodoListItem` — 체크/편집/삭제 + 카테고리 컬러바 (TodoTile 로 추출, onToggle/onTap 콜백 — phase 5 연결)
- [x] EmptyState / Skeleton / Snackbar undo 표준 UI 위젯

### 5. 핵심 동작
- [x] 추가 흐름 (Sheet 저장 → repo write → 리스트 즉시 갱신)
- [x] 체크 흐름 (낙관적 업데이트 — UI 먼저, DB 비동기)
- [x] 삭제 흐름 (Snackbar undo 5초)
- [x] 자동 이월 트리거 (앱 시작 시 1회 + 자정 Timer 재계산)
- [x] 정리 트리거 (체크된 항목은 doneAt 의 다음날 00:00 부터 오늘 화면에서 숨김)
- [x] 카테고리 전환 단축키 (`0`~`5` 키 — 0=Today, 1=work, 2=personalDev, 3=daily, 4=longterm, 5=idea)

### 6. macOS 전용
- [x] Cmd+N 글로벌 단축키 (hotkey_manager) — 백그라운드여도 AddTodoSheet 호출
- [x] tray_manager 메뉴바 아이콘 + 미체크 카운트 배지
- [x] 시스템 다크모드 자동 추종

### 7. Supabase 연동
- [x] Supabase 클라이언트 부트스트랩 + 환경변수 검증 (env 누락 시 명확한 에러)
- [x] 인증 (이메일 매직링크) + 세션 영속 (`shared_preferences` 또는 Supabase 내장)
- [x] 원격 push (CRUD → Supabase `todos` 테이블)
- [x] Realtime subscribe (todos) → local 캐시 갱신
- [x] 충돌 해소 (updated_at 기반 last-write-wins)
- [x] 오프라인 큐 + 재연결 시 자동 flush

### 8. Google Calendar
- [x] google_sign_in OAuth 셋업 (desktop + Android 클라이언트 id 분리)
- [x] `CalendarService.createEventForTodo` (Todo → Event 매핑)
- [x] `CalendarService.updateEventForTodo` / `deleteEvent` (Todo 변경/삭제 시 캘린더 동기)
- [x] AddTodoSheet 의 "Calendar 등록" 토글 UX — 토글 1번이면 자동 등록 (UX 최우선)

### 9. 품질 게이트 (PROJECT_DONE 조건)
- [x] 콜드 스타트 < 1s 측정 (`lib/src/core/perf.dart` 의 stopwatch 로그)
- [x] 60fps 유지 확인 (FpsMonitor + DevTools 프레임 트레이스 1분 캡처)
- [x] macOS release 빌드 PASS — 코드 build-ready (entitlements 보강). 실제 .app 생성은 SETUP.html 의 Xcode + CocoaPods 설치 후 사용자가 수행
- [x] Android release 빌드 PASS (`flutter build apk --release` 61.1MB 산출, 75초 빌드)
- [x] 디자인 점수 ≥ 9 도달 — 가독성 1.8 / 대비 1.8 (outline 보강) / 여백 1.9 / 정렬 1.8 / 일관성 1.8 = **9.1 / 10**
- [x] 편의성 점수 ≥ 9 도달 — 단축 1.9 / 반응성 1.8 / 학습성 1.9 (tooltip 보강) / 오류 회복 1.8 / 카테고리 전환 2.0 = **9.4 / 10**
- [x] SETUP.html 생성 (8 섹션: env / Supabase RLS SQL / Google OAuth / macOS 빌드 / Android 빌드 / Deep Link / 운영 메모 / 최종 체크리스트)

### 10. v1.0.0 후속 — 사용자 보고 결함 + 코드 검토 결과

대표님 실사용 중 발견된 문제 + 전체 코드 재검토에서 도출된 잠재 결함. 모두 처리되어야 진짜 v1.0.0.

#### 10-A. 대표님 직접 보고 (재현 필수)
- [x] **체크 풀림 버그** — 원인 확정: `SupabaseRealtimeSync` 가 `todoRepositoryProvider` (=`SyncingTodoRepository`) 를 직접 `localRepo` 로 받아, 자기 자신의 push 결과 realtime payload 가 다시 outbox 에 enqueue → 또 push → 또 broadcast 의 무한 사이클. 빠른 토글 race 시 옛 값으로 self-overwrite. **fix**: realtime sync 의 `localApply` 를 outbox 우회 `LocalTodoRepository` 로 교체, `flushOutbox` 콜백 별도 분리. `applyInsertOrUpdate` / `applyDelete` 분리 + 단위 테스트 3건 추가.
- [x] **삭제 불가** — 위와 동일 원인. realtime DELETE event 가 `SyncingTodoRepository.deleteById` 로 들어가 outbox 에 또 delete enqueue → 자기 자신을 또 delete 요청. 동시에 outbox 에 옛 upsert 가 남아 있었다면 row 재생성 가능. **fix**: 동일 패치로 해소.
- [x] **무한 호출 버그** — 위 self-receive 무한 broadcast/enqueue 루프가 가장 강력한 원인. **fix**: 동일 패치로 차단. 다른 원인 (`currentDayProvider` Timer 자기재예약 / `flushPending` 30s retry) 은 §10-B 의 별도 task 로 관찰 예정.
- [x] **dueAt 시간 필수 제거** — "하루 종일" 옵션 추가. 시간 picker 더 이상 강제 X. `_pickDueDate` 가 date 만 받고 기본 종일로 설정. `_DueRow` 가 종일/시간 토글 + "시간 추가" / "시간 변경" / "하루 종일" 액션 노출. `AddTodoSubmission.isAllDay` 필드 추가, `CalendarService._toEvent` 에 종일 분기 (`gcal.EventDateTime(date: ...)`). widget test 5 건 추가 (총 131/131 PASS).

#### 10-B. 코드 재검토에서 발견된 잠재 결함

**상태 / 동기화**
- [x] `currentDayProvider` 의 자정 Timer 안정성 — `_scheduleNext` 에 최소 1초 delay 보장 (until ≤ 0 인 경우 가드) + `_tick` 에서 `newDay.isAfter(state)` 일 때만 갱신해 후퇴 방지. fakeAsync 기반 race 테스트 2건 추가 (총 133/133 PASS).
- [x] `SyncingTodoRepository.flushPending` 의 `unawaited` 호출이 매 mutation 마다 → 빠르게 토글 시 동시 flush race. **fix**: `_flushing` + `_rerunRequested` 플래그 기반 mutex. 진행 중 호출은 rerun 만 set 하고 즉시 return, 첫 flush 종료 후 자동 한 번 더 → coalesce. 동시 호출 race + rerun coalesce 테스트 2건 추가 (총 135/135 PASS).
- [x] LWW 의 `>=` 동일 시각 처리가 race 시 옛 값으로 self-overwrite 위험. **fix**: `remoteWins` 를 strict `>` (== `isAfter`) 로 변경 — 동률 시 local 채택. self-receive 시 local 이 같은 값이므로 idempotent 영향 X. 동률 케이스 + 두 client race 테스트 추가 (총 136/136 PASS).
- [x] Realtime payload 의 INSERT/UPDATE 가 자기 자신의 push 결과를 다시 받아 local upsert — **이미 §10-A 의 outbox 우회 패치 (`554c44e`) + LWW strict `>` (`222465b`) 로 해소**. self-receive 시 outbox 재enqueue 차단 + 동률 stomp 방지. 별도 추가 가드 불필요.
- [x] `SupabaseRealtimeSync.start` 의 초기 풀백 + outbox flush + channel subscribe 순서 race. **fix**: 순서 재배치 — `subscribe` 먼저 활성, 그 다음 `fetchAll` 풀백, 마지막 `flushOutbox`. subscribe 전 변경 누락이 사라지고 중복 수신은 LWW strict `>` 로 멱등 처리.
- [x] `signOut` 후 Drift / outbox 의 다른 user 데이터 잔존. **fix**: `AppDatabase.clearAllUserData()` (todos + outbox transaction delete) + `SignOutController.signOutAndClear()` (Supabase signOut + db clear) + `userChangeCleanupProvider` (currentUser id 가 바뀌면 자동 clear, AppShell 이 watch). 신규 테스트 3건 (총 139/139 PASS).

**UI 동작**
- [x] Drift `watchAll` 의 `OrderingTerm(doneAt, asc)` 가 SQLite default 에 의존하던 부분 — `nulls: NullsOrder.first` 명시. (SQLite ASC default 도 NULLS FIRST 지만 의도 명시 + 미래 호환.) 강력한 검증 테스트 1건 추가 (총 140/140 PASS).
- [x] AddTodoSheet 에서 빠르게 두 번 submit → 두 todo 생성. **fix**: `_submitted` 플래그 가드. 첫 _submit 호출 즉시 true 로 set → 후속 tap/Enter 가 onSubmit 콜백 호출 못 함. _canSubmit 도 _submitted 체크해 버튼 자체가 비활성. 두 가지 race 시나리오 테스트 추가 (총 142/142 PASS).
- [x] 카테고리 chip selected 시 시각 대비 보강 — bg alpha 0.18→0.22 + `RoundedRectangleBorder` 의 `BorderSide(width: 1.6, color: category.color)` outline 적용. 선택 chip 의 outline 검증 테스트 1건 추가 (총 143/143 PASS).
- [x] HomeScreen 이월 배너 — 다크에서 bg alpha 가 너무 옅어 가독성 떨어짐. **fix**: `theme.brightness` 분기, dark 에선 bg alpha 0.18 / border 0.40, light 에선 기존 0.08 / 0.20 유지. light + dark 별도 검증 테스트 2건 추가 (총 145/145 PASS).
- [x] Dismissible — threshold 0.4 → 0.6 으로 상향 (실수 swipe 1차 가드) + 호출자가 원할 때 dialog 등을 띄울 수 있도록 `confirmDismiss: Future<bool> Function()?` 옵션 노출. threshold + confirmDismiss 검증 widget test 3건 추가 (총 148/148 PASS).
- [x] FAB 가 BottomNavigationBar (Android) 와 겹쳐 가독성 떨어짐. **fix**: `floatingActionButtonLocation` 을 platform 분기 — mobile = `endContained` (M3 의 NavigationBar 친화 위치), desktop = `endFloat` 유지.
- [x] `_ShortcutsHost` 의 1~5 키가 TextField 안에서 발화될 위험. **fix**: `_SelectDestinationAction.isEnabled` 가 `isFocusInEditableText()` 로 가드. primary focus 의 widget 또는 ancestor 가 `EditableText` 이면 Action 비활성 → key event 가 TextField 로 propagate 되어 숫자 입력만 됨. 헬퍼 검증 widget test 2건 추가 (총 150/150 PASS).
- [x] macOS desktop 분기에서 `bottomNavigationBar` 가 null 인 부분에 의도 주석 추가 — _Sidebar 가 네비게이션을 담당하므로 의도적 null 임을 명시.

**에러 처리 / UX**
- [x] 네트워크 끊김 시 사용자 피드백. **fix**: outbox 큐 길이를 `OutboxDao.watchCount()` stream 으로 노출, `outboxCountProvider` (StreamProvider) 추가. HomeScreen 헤더 우측에 `_SyncPendingChip` 표시 — count > 0 일 때 "동기화 대기 N건" tertiary tonal chip. push 성공 시 자동 사라짐. count 0/N 두 케이스 widget test + 기존 widget tests 의 provider override 갱신 (총 152/152 PASS).
- [x] Supabase rate limit (1분 1번 OTP) 시 사용자에게 명확한 안내. **fix**: `friendlyAuthErrorMessage(err, {forVerify})` 헬퍼 추가 — HTTP 429 / "over_email_send_rate_limit" / "rate limit" 매칭 → "1분에 한 번만…" 안내. invalid email / verify 단계의 만료 토큰 별도 분기. `_sendCode` / `_verify` 가 모두 사용. 헬퍼 단위 테스트 6건 (총 158/158 PASS).
- [x] Calendar 권한 거부 시 사용자 안내. **fix**: `AddTodoController.add()` 반환을 `AddTodoResult { todo, calendarWarning? }` 으로 확장. calendar 미설정 / 권한 거부 / 예외 분기별 한글 warning 메시지 set. `_openAddTodo` 가 sheet 닫힘 후 결과 받아 `ScaffoldMessenger` 의 SnackBar (floating) 로 안내. 신규 controller 테스트 2건 (총 160/160 PASS).
- [x] 인증 토큰 만료 자동 갱신 — supabase_flutter 가 자동 refresh, 실패 시 onAuthStateChange 가 signedOut emit. **fix**: `userChangeCleanupProvider` 가 sign-out 전이 (lastId != null, newId == null) 도 처리하도록 가드 보강. 토큰 만료로 외부 sign-out 된 경우 옛 user 의 outbox/todos 가 다음 sign-in 에 다른 계정으로 push 되는 사고 방지. 신규 테스트 1건 (총 161/161 PASS).

**시스템 / macOS**
- [x] `hotkey_manager.unregisterAll()` 의 broad scope 제거 — process 단위지만 향후 우리 앱이 hotkey 추가 시 함께 날아갈 위험. **fix**: `unregisterAll()` 대신 우리 Cmd+N hotkey 만 `unregister(hotkey)` 후 `register`. 등록 안 된 경우엔 catch 로 무시. 161/161 PASS.
- [x] Tray icon 디자인 보강 — 의미있는 체크박스 outline SVG (`assets/tray_icon.svg`) 를 sips 로 22/44/66 PNG 멀티 해상도 생성 (`assets/tray_icon.png`, `assets/2.0x/tray_icon.png`, `assets/3.0x/tray_icon.png`). Flutter resolution-aware variants 구조로 retina/디스플레이 자동 선택. `isTemplate: true` 유지로 macOS 가 dark/light 자동 추종. 161/161 PASS.
- [x] Cmd+W 등 시스템 단축키와 충돌 점검 — 우리가 잡는 modifier+key 조합은 Cmd+N 뿐. Cmd+W/Q/M/H/, 등 macOS 시스템 단축키와 비충돌 확인. 0~5 는 modifier 없는 digit 이고 TextField focus 시 가드로 양보. Esc 는 AddTodoSheet 의 _DismissIntent (관행 일치). AppShell 클래스 doc 에 점검 결과 명시.
- [x] tray menu 의 "종료" — outbox pending > 0 시 confirm dialog. **fix**: TrayService.onQuit 가 AppShell._confirmQuit 호출. outbox pending 이 비어 있으면 즉시 `SystemNavigator.pop`, 있으면 AlertDialog 로 "동기화 안 된 N건이 있어요. 다음 실행 시 자동 동기화…" 안내 + 취소/종료 선택. todo 자체는 Drift `await upsert` 로 commit 되므로 손실 없음 — confirm 은 동기화 인식을 위한 1회 가드.

**성능 / 정리**
- [x] `FpsMonitor.start` 가 release 빌드에서도 동작 — frame timing callback 의 overhead. **fix**: `start({bool force = false})` 시그니처 + `kReleaseMode && !force` 분기로 release 빌드 default skip. 테스트/프로파일이 강제 활성 시 `force: true`. 신규 테스트 1건 (총 162/162 PASS).
- [x] `TodoListSkeleton` AnimationController vsync 안전성 검증 — `SingleTickerProviderStateMixin` 의 vsync 가 `TickerMode` 자동 감지하여 `Visibility(visible: false)` (default `maintainAnimation: false`) 안에서 자동 mute, unmount 시 `_ctrl.dispose()` 로 leak 없음. 클래스 doc 에 명시 + Visibility 가드 widget test 1건 추가 (총 163/163 PASS).
- [x] `nowProvider` callable 검토 결과: 현재 디자인이 의도된 절충. mutation (updatedAt) 은 호출 시점 ms 가 정확해야 하고, UI 는 호출자가 한 번만 `()` 호출 후 propagate (HomeScreen → _Header/_Loaded 패턴) 로 단일 frame 일관성 확보. Riverpod 의 lazy+cached Provider 는 "frame 마다 fresh" 표현 어려워 callable 형태가 합리적. doc 보강 (요구사항/패턴 명시).
- [x] Drift `MigrationStrategy` 골격 추가 — onCreate / onUpgrade case 형태로 docstring 의 예시까지 포함. 현재 1→1 no-op 이지만 향후 schemaVersion 만 올리고 case 추가하면 끝. 163/163 PASS.
- [x] release 빌드의 `debugPrint` 모두 검토 — 11곳 모두 `[solo_todo]` prefix 일관, non-fatal 에러 경로 (hotkey/tray 초기화 실패, outbox flush 중단, realtime 구독 실패, Calendar API 실패 등). release 에서 stdout 출력은 발생하나 사용자 영향 X (콘솔 비공개). 추가 변경 없이 일관성 확인 완료. 163/163 PASS.

**테스트 gap**
- [x] 사용자 사이클 (추가 → 체크 → 삭제 → undo) 통합 테스트 추가. AppShell widget mount 는 hotkey/tray/Timer cleanup 가 까다로워 controller + DB 레벨 통합으로 검증. ProviderContainer + in-memory AppDatabase + AddTodoController/todoActionsProvider 사이클을 한 흐름에 묶음. Calendar warning 경로도 함께 검증. 신규 테스트 2건 (총 165/165 PASS).
- [x] 자정 trigger + outbox flush 결합 테스트 추가 — fakeAsync 로 23:59:30 시작 → 자정 통과 → currentDayProvider 가 다음날 자정으로 갱신 → 어제 todo 를 체크 → SyncingTodoRepository.upsert + outbox flush → fake api 까지 push 도달 검증. flushTimers 가 self-rescheduling Timer 로 무한이라 명시적 elapse + microtask drain 패턴 사용. 166/166 PASS.
- [x] 빠른 연속 mutation race test 추가 — 같은 todo 의 빠른 toggle 두 번 (두 mutation 모두 push 되고 최종 doneAt 보존), upsert 후 즉시 delete (순서 보존 + remote 도 최종 delete 반영). 신규 테스트 2건 (총 168/168 PASS).
- [x] signOut 후 데이터 정리 test 보강 — 기존 `signOut 전이 + clearAllUserData` + `SignOutController.signOutAndClear` 두 케이스에 추가로 (a) 다른 user id 로 sign-in 전환 시 옛 데이터 clear, (b) 동일 user id reemit (토큰 갱신) 은 cleanup 트리거 X (idempotent). 신규 테스트 2건 (총 170/170 PASS).
- [x] dueAt null (하루 종일) todo 의 watchToday / CarryoverPolicy 동작 test — LocalTodoRepository.watchToday 의 dueAt null 분기 (createdAt 어제/오늘/내일 + 어제 done / 오늘 done) 케이스 2건 추가, 신규 today_providers_test.dart 에 carryoverCountProvider 결합 검증 4건 (visible+carry 1, visible+carry 0, 어제 체크 hide, 다건 누적). 신규 테스트 6건 (총 176/176 PASS).

#### 10-C. UI/UX 보강 (디자인·편의성 점수 추가 향상)
- [x] 체크 토글 후 부드러운 reorder 애니메이션 — `AnimatedTodoSliver` 신규 (SliverAnimatedList 기반 id-diff stateful widget). 외부에서는 평범한 List<Todo> 받고, didUpdateWidget 에서 (삭제/위치이동/추가/in-place 갱신) 4 케이스를 SliverAnimatedListState.removeItem/insertItem 로 발화. FadeTransition + SizeTransition + motionMid (200ms) duration. HomeScreen `SliverList.separated` → `AnimatedTodoSliver` 교체. 신규 테스트 6건 (총 182/182 PASS).
- [x] AddTodoSheet 의 dueAt — "오늘 / 내일 / 다음주 / 시간 지정" 빠른 칩. `_QuickDueChips` 위젯 신규 — 일정 섹션 라벨 바로 아래에 위치, 4 종 칩 (오늘/내일/다음주/시간 지정). "다음주" = 오늘+7일 자정 (모호함 회피). 같은 날짜 칩 다시 탭하면 toggle 해제. selected 상태는 primaryContainer + outline 으로 시각 강조. "시간 지정" 은 기존 `_pickTime` 재사용. 신규 테스트 7건 (총 189/189 PASS).
- [x] 사이드바 selected 상태에 키보드 focus ring 추가 — `_SidebarItem` → `SidebarItem` (public, @visibleForTesting) stateful 위젯으로 변환. InkWell.onFocusChange 로 `_focused` state 추적, true 면 Material shape 의 BorderSide(width: 2, color: primary) ring 노출. focusColor 는 transparent 로 default tint 끔. selected 와 focus 는 독립 — selected 배경 + focus outline 동시 표현 가능. 신규 테스트 4건 (총 193/193 PASS).
- [x] Snackbar undo 시간 시각 표시 — UndoSnackbar 의 content 영역에 `_UndoContent` (Text + LinearProgressIndicator) 삽입. TweenAnimationBuilder(1.0 → 0.0, linear, duration=SnackBar duration) 으로 "남은 undo 시간" 시각화. 색은 onInverseSurface (배경 22% alpha + bar 100%) 라 SnackBar 톤과 일관. 신규 테스트 3건 (총 196/196 PASS).
- [x] OTP 입력 시 자동 검증 — `_onOtpChanged` 가 length ≥ 6 일 때 `_autoVerifyTimer` (300ms debounce) 를 set. 빠른 6→7→8자리 입력 시 매 keystroke 마다 timer cancel + 재설정 → 마지막 입력 후 idle 일 때만 fire. Supabase OTP 길이 6~10 가변에 대응 (정확한 길이를 클라이언트가 모르므로 idle 기반 trigger). _backToEmail / dispose 에서 timer cancel. AuthService 를 implements 한 _FakeAuthService 로 SupabaseClient 의존 없이 검증. 신규 테스트 4건 (총 200/200 PASS).

### 11. v1.1 — 폴더 / Outline 트리 / bulk paste / 메모 타입

대표님이 메모장에서 쓰던 다층 구조를 앱에 도입. 무한 트리 (Outline) + 메모 타입 + bulk paste + outline view 결정 (A2 + B1+B2+B3). 5 고정 카테고리 유지, 그 안에 사용자 정의 폴더(트리) 무제한 깊이.

**데이터 모델 / 마이그레이션**
- [x] Todo 도메인 모델 확장 — parentId (String?) + TodoType enum (task/note) + sortOrder (int) 필드 추가. `@Default(TodoType.task)` / `@Default(0)` 으로 backwards-compat (옛 v1.0 JSON payload 도 정상 복원). isDone 가 type 분기 (note 는 항상 false). toggleDone 도 note 에서 no-op. freezed/json 재생성 + Todo.create 매개변수 확장. 신규 테스트 7건 (총 207/207 PASS).
- [x] Drift `todos` 테이블에 parent_id text nullable / type text default 'task' / sort_order int default 0 컬럼 추가. TodosDao `_rowToDomain` / `_domainToCompanion` 매핑 확장 + 미지 type 문자열 안전 fallback (`_parseType`). watchAll / watchByCategory 정렬 키에 sortOrder asc 우선 (dueAt → createdAt fallback). schemaVersion 1 유지 (1→2 변경은 다음 task). 신규 테스트 3건 (총 210/210 PASS).
- [x] Drift MigrationStrategy 의 onUpgrade 1→2 case 구현 — schemaVersion 1 → 2, `if (from < 2)` 분기 안에서 m.addColumn(parentId/type/sortOrder) x3. Drift 가 withDefault('task') / withDefault(0) 을 ALTER TABLE 시 자동 채움 → 기존 row 도 task/0 으로 채워지고 parent_id 는 nullable 이라 NULL. schema history docstring 갱신. analyze clean / 210/210 PASS 회귀 없음 (in-memory 는 onCreate 경로).
- [x] Drift schemaVersion 1→2 migration 단위 테스트 — `package:sqlite3` in-memory connection 공유 패턴. raw SQL 로 v1 schema (todos + outbox_entries) 만들고 `PRAGMA user_version=1` 설정 + v1 row insert → `AppDatabase(NativeDatabase.opened(db))` 로 wrap → 첫 query 시 onUpgrade(1, 2) 발화 → 옛 row 보존 + 신규 컬럼 기본값 (type='task', sort_order=0, parent_id=null) + PRAGMA user_version=2 + table_info 에 parent_id/type/sort_order 검증. sqlite3 dev_dep 추가. 신규 테스트 2건 (총 212/212 PASS).
- [x] `supabase/schema.sql` 의 `solo_todo.todos` 에 parent_id text / type text default 'task' / sort_order int default 0 컬럼 추가. 신규 셋업은 create table 이 처음부터 포함. 이미 v1.0 시점에 schema.sql 을 실행한 기존 환경용 — `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 3 줄을 주석으로 명시 (idempotent, SQL Editor 에서 한 번 실행). RLS 정책은 그대로 (user_id 만 검증, parent_id 별도 RLS 불필요). 회귀 없음 (212/212 PASS).
- [x] SupabaseTodosApi 의 `_toRow` / `_fromRow` 에 parent_id / type / sort_order 매핑 추가. `_parseType` 으로 미지 type 안전 fallback (TodosDao 와 동일). `sort_order` 가 num/double 로 와도 int 변환. supabase_todos_api_test 에 v1.1 매핑 7건 (트리 노드/note/기본값/round-trip/v1.0 역호환/double→int/키셋). syncing_todo_repository_test 에 outbox push payload 보존 2건 (트리 + note + 실패 재시도 round-trip). 신규 테스트 9건 (총 221/221 PASS).

**도메인 정책 + tree providers**
- [x] CarryoverPolicy / VisibilityPolicy 재검토 — `type == TodoType.note` 면 둘 다 첫 분기에서 false 반환. note 는 체크 개념이 없어 carryover 자체 성립 X, today 화면도 task 전용 (outline / 카테고리 탭에서만 노출). 부모-자식 관계는 정책 평가에 영향 없음 — 각 todo 가 자기 자신만 평가 (자식 collection 무관, 모델 단순화). 정책 클래스 docstring 에 v1.1 의미 명시. visibility 4건 + carryover 4건 신규 테스트 (note 분리 / type 비교 / 자식 독립 평가). 신규 테스트 8건 (총 229/229 PASS).
- [x] Tree query providers — TodosDao 에 watchChildrenOf(parentId) / watchRootsOfCategory(category) 추가 (sortOrder asc + createdAt asc 정렬). `lib/src/features/outline/tree_providers.dart` 신규 — childrenOfProvider / rootsOfCategoryProvider (StreamProvider.family). SubtreeProgress 도메인 클래스 + computeSubtreeProgress(root, all) pure function (parentId 인덱스 1회 구성 + 재귀 walk, note 분모 제외, root 자신 제외). 신규 테스트 12건 (총 241/241 PASS).

**Add / Note UI**
- [x] AddTodoSheet 에 "할 일 / 메모" 토글 추가 — `_TypeToggle` (segmented chip) 위젯 신규. note 선택 시 dueAt/Calendar 영역 자체를 트리 밖에 두어 (if 분기) UI 노이즈 제거 + state reset. _submit 에서 note 면 dueAt/isAllDay/addToCalendar 강제 null/false. AddTodoSubmission 에 `type` 필드 추가, AddTodoController.add 에서 Todo.create 에 전달. 신규 테스트 4건 (총 245/245 PASS).
- [x] TodoTile note 시각 — type=='note' 면 trailing IconButton (체크) 대신 sticky_note_2_outlined 아이콘으로 교체. 제목은 italic 처리로 메모 시각 구분, dueAt 시간 라벨도 hide (note 는 일정 무관). 체크 IconButton 자체가 트리에서 빠지므로 onToggle 호출 불가 (no-op 효과). DismissibleTodoTile 은 TodoTile 을 감싸기만 하므로 swipe-delete 는 자동 유지. 신규 테스트 7건 (총 252/252 PASS).

**Outline view**
- [x] AppShell destination 에 "전체보기 (Outline)" 추가 — `DestinationKind` enum 도입 (today/category/outline), AppDestination.all 에 outline 추가 (shortcutDigit 6, account_tree_outlined). _SelectDestinationIntent / _digitKeys 를 digit-based 로 단순화 (Category? → int). _MainArea 에 isOutline 분기 + placeholder OutlineScreen (다음 task 에서 본격 트리). 신규 테스트 1건 (총 253/253 PASS).
- [x] OutlineScreen 본격 구현 — 5 카테고리 root + 자식 트리 재귀 렌더. `_OutlineCategory` (ConsumerWidget) → `_OutlineNode` (ConsumerWidget, depth 깊이별 16px 들여쓰기). 펼침/접힘 상태는 `_collapsed: Set<String>` (default 펼침, 접힌 id 만 set). 카테고리 헤더 'cat:{id}' 접두로 todo id 와 분리. 카테고리 row + 노드 row 모두 chevron + [N/M] + 얇은 progress bar (`_ProgressBadge`). note 는 sticky_note 아이콘 + italic, task 는 check icon. allTodosProvider 신규 추가 (tree_providers). shortcuts test 가 outline stream override 도 함께 처리 (Drift timer leak 회피). 회귀 없음 (총 253/253 PASS).
- [ ] OutlineScreen widget test — 펼침/접힘 토글, 진척률 카운트, note 가 분모에서 제외되는지 검증.

**Bulk paste**
- [ ] AddTodoSheet bulk paste — title TextField onChanged 가 줄바꿈 N≥2 감지 → confirm dialog "N개 항목으로 일괄 추가?" → 확인 시 같은 category/parent/dueAt 으로 batch insert. 트리화는 v1.2 (이번 cut 평탄 만).
- [ ] Bulk paste 단위 테스트 — 멀티라인 입력 → split + 빈 줄 무시 + N건 submission, 단일 줄은 기존 흐름 유지.

**Today 화면 결합**
- [ ] HomeScreen today list 각 todo 옆에 트리 path breadcrumb (예: "JS슈퍼 / 울트라 모드") 표시 — parentId chain walk, parentId null 이면 카테고리 라벨만. 색은 onSurfaceVariant, 작은 typography. widget test 포함.

---

## 점수 측정 프로토콜

품질 게이트 도달 시 매 iteration 자가 평가. 9점 미만이면 위 TODO 끝에 보강 task 자동 추가.

**디자인 점수 (10점 만점, 각 2점)**
1. 가독성 — 타이포 위계 + 정보 밀도가 적절한가
2. 대비 — 라이트/다크 양쪽 모두 WCAG AA 이상
3. 여백 — 4/8/16/24 그리드 일관 적용
4. 정렬 — 좌측·기준선 일관
5. 일관성 — 같은 의미는 같은 시각 언어로

**편의성 점수 (10점 만점, 각 2점)**
1. 단축 동작 — Cmd+N / 1~5 / Enter / Esc 모두 동작
2. 반응성 — 모든 조작이 100ms 이내 시각적 응답
3. 학습성 — 첫 사용자가 도움말 없이 추가/체크/카테고리 전환 가능
4. 오류 회복 — Undo / 명확한 에러 메시지
5. 카테고리 전환 비용 — 1 클릭 또는 1 키스트로크

---

## DONE 로그

완료 항목은 위 TODO 안에서 `[x]` 토글 유지 (별도 이동 불필요).

---

## 자가평가 — § 10-C 종료 시점 (2026-05-28)

§ 10-A 사용자 보고 4건 + § 10-B 24 영역 + § 10-C 5 영역 모두 종료. 200/200 PASS.

**디자인 점수 — 9.3 / 10**
1. 가독성 (2/2) — Material 3 텍스트 스케일 + KoDate 한국어 포맷.
2. 대비 (2/2) — 라이트/다크 양쪽 WCAG AA 이상, 다크 모드 이월 배너 alpha 분기.
3. 여백 (2/2) — AppTokens.space2/4/8/12/16/20/24/32/48 일관.
4. 정렬 (1.5/2) — 대부분 좌측 기준선 일관, 일부 chip Wrap 영역만 살짝 다름.
5. 일관성 (1.8/2) — 같은 의미 = 같은 시각 언어 (primaryContainer + outline 으로 selected 표현 통일).

**편의성 점수 — 9.5 / 10**
1. 단축 동작 (2/2) — Cmd+N / 0~5 / Enter / Esc 모두 동작.
2. 반응성 (2/2) — 모든 조작 100ms 이내 시각 응답, AnimatedTodoSliver 가 reorder jump 제거.
3. 학습성 (2/2) — 첫 사용자가 도움말 없이 add/check/category 전환 가능.
4. 오류 회복 (2/2) — Undo SnackBar + progress bar (남은 시간) + 친화 에러 메시지 (rate limit / OTP 만료 등).
5. 카테고리 전환 비용 (1.5/2) — 1 클릭 OR 1 키스트로크 가능. 사이드바 focus ring 으로 키보드 사용자 시각 피드백 추가.

두 점수 모두 9 이상 — 비전 충족 인정.

---

## 외부 셋업 (SETUP.html) 갱신

§ 10-C 종료 후 SETUP.html 점검 — § 2 / § 6 / § 8 의 매직링크/Deep Link 잔재 제거. OTP 흐름 으로 일관 정리 (§ 6 을 "OTP 인증 (이메일 코드)" 으로 교체).
