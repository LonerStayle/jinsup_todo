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
- [ ] Supabase 클라이언트 부트스트랩 + 환경변수 검증 (env 누락 시 명확한 에러)
- [ ] 인증 (이메일 매직링크) + 세션 영속 (`shared_preferences` 또는 Supabase 내장)
- [ ] 원격 push (CRUD → Supabase `todos` 테이블)
- [ ] Realtime subscribe (todos) → local 캐시 갱신
- [ ] 충돌 해소 (updated_at 기반 last-write-wins)
- [ ] 오프라인 큐 + 재연결 시 자동 flush

### 8. Google Calendar
- [ ] google_sign_in OAuth 셋업 (desktop + Android 클라이언트 id 분리)
- [ ] `CalendarService.createEventForTodo` (Todo → Event 매핑)
- [ ] `CalendarService.updateEventForTodo` / `deleteEvent` (Todo 변경/삭제 시 캘린더 동기)
- [ ] AddTodoSheet 의 "Calendar 등록" 토글 UX — 토글 1번이면 자동 등록 (UX 최우선)

### 9. 품질 게이트 (PROJECT_DONE 조건)
- [ ] 콜드 스타트 < 1s 측정 (`lib/src/core/perf.dart` 의 stopwatch 로그)
- [ ] 60fps 유지 확인 (DevTools 프레임 트레이스 1분 캡처)
- [ ] macOS release 빌드 PASS (`flutter build macos --release`)
- [ ] Android release 빌드 PASS (`flutter build apk --release`)
- [ ] 디자인 점수 ≥ 9 도달 (가독성/대비/여백/정렬/일관성 각 2점)
- [ ] 편의성 점수 ≥ 9 도달 (단축/반응성/학습성/오류 회복/카테고리 전환 각 2점)
- [ ] SETUP.html 생성 (Supabase URL/Key 발급 가이드, Google OAuth 클라이언트 발급 가이드, RLS SQL, 빌드/실행 명령)

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
