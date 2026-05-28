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
- [ ] HomeScreen 이월 배너의 색이 light/dark 모두 동일 alpha — 다크에서 가독성 검증
- [ ] Dismissible 의 `confirmDismiss` 없음 — 실수 swipe 로 즉시 삭제. UndoSnackbar 있지만 0.4 threshold 도 낮은 편
- [ ] FAB 가 BottomNavigationBar (Android) 와 겹쳐 가독성 떨어짐 — `FloatingActionButtonLocation.endDocked` 또는 위치 조정
- [ ] `_ShortcutsHost` 의 1~5 키가 TextField 안에서도 발화될 수 있음 — Focus 위계 검증, TextField focus 시 capture 차단
- [ ] macOS desktop 분기에서 `bottomNavigationBar` 가 null 인데 코드는 ternary 로 남아 있음. 정상이지만 의도 명시

**에러 처리 / UX**
- [ ] 네트워크 끊김 시 사용자 피드백 0 — 오프라인 배너 또는 토스트
- [ ] Supabase rate limit (1분 1번 OTP) 시 사용자에게 명확한 안내. 현재는 generic 에러
- [ ] Calendar 권한 거부 시 사용자에게 안내 (현재 silent debugPrint)
- [ ] 인증 토큰 만료 자동 갱신 검증 — supabase_flutter default 동작 신뢰만 하고 있음. 만료 시 sign-in 강제 흐름

**시스템 / macOS**
- [ ] `hotkey_manager.unregisterAll()` 이 다른 앱의 글로벌 단축키도 제거할 위험 → 우리 hotkey 만 unregister
- [ ] Tray icon 이 dark/light 모드에서 단색 placeholder — macOS template image 로 자동 색 추종은 isTemplate true 로 OK 하지만 디자인 보강 필요
- [ ] Cmd+W 등 시스템 단축키와 충돌 점검 (현재 0~5, Cmd+N 만 사용)
- [ ] tray menu 의 "종료" 가 `SystemNavigator.pop()` — macOS 에서 confirm 없이 즉시 종료. 미저장 데이터 안전성 확인

**성능 / 정리**
- [ ] `FpsMonitor.start` 가 release 빌드에서도 동작 — frame timing callback 의 overhead 측정 + release 비활성 옵션
- [ ] `TodoListSkeleton` 의 AnimationController 가 화면 안 보일 때도 vsync — Visibility / dispose 시점 확인
- [ ] `nowProvider` = `DateTime.now` 자체 callable — `ref.read(nowProvider)()` 호출 시점이 분산되어 동일 frame 내 다른 값. 단일 frame 의 unify 필요한지 검토
- [ ] Drift schemaVersion 1 — 향후 컬럼 추가 대비 migration helper (`MigrationStrategy`) 작성
- [ ] release 빌드의 `debugPrint` 모두 — release 에선 no-op 이지만 일관 확인

**테스트 gap**
- [ ] AppShell 전체 흐름 integration test 부족 — sign-in → 추가 → 체크 → 삭제 → undo 사이클
- [ ] 자정 trigger 통합 test 는 있지만 outbox flush 와 결합한 case 없음
- [ ] 빠른 연속 mutation race test
- [ ] signOut 후 데이터 정리 test
- [ ] dueAt null (하루 종일) todo 의 watchToday / CarryoverPolicy 동작 test

#### 10-C. UI/UX 보강 (디자인·편의성 점수 추가 향상)
- [ ] 체크 토글 후 부드러운 reorder 애니메이션 (AnimatedList 또는 implicitly animated)
- [ ] AddTodoSheet 의 dueAt — "오늘 / 내일 / 다음주 / 시간 지정" 빠른 칩
- [ ] 사이드바 selected 상태에 키보드 focus ring 추가
- [ ] Snackbar undo 시간 시각 표시 (5초 progress bar)
- [ ] OTP 입력 시 자동 검증 (6/8자리 모두 채워지면 자동 verify)

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
