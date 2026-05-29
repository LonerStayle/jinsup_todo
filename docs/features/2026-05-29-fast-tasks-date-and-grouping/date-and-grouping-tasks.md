# 날짜·기간 + 그룹 계층 — Fast tasks (5개)

> /fast-tasks 배치. Socratic 확정: 1A / 2A / 3A / 4B.
> 대표님 실기기(맥 + 갤S24) 검증 중 나온 5개 요구. v1.2 후속(`6ffe62f`) 위에 쌓는다.

---

## Task 1: 하루종일 저장 시 00:00 표시 제거

- **명세**: '하루종일' 모드 todo 는 시간 컴포넌트를 의미 없는 값으로 보고, 화면 어디에도 `00:00`(또는 오전 12:00) 을 찍지 않는다. 날짜만 표시.
- **구현 핵심**: 새 `isAllDay` 플래그 (Task 4/5 의 모델에 포함) 가 true 면 date_format / TodoTile / breadcrumb 에서 시간 생략.
- **영향 파일**: `lib/src/core/date_format.dart`, `lib/src/ui/widgets/todo_tile.dart`, today breadcrumb (`lib/src/features/home/`), `lib/src/domain/todo.dart`
- **소속**: Chain A (Task 4·5·1 한 묶음)

## Task 4: 기간 범위 지원 (시작일~종료일, 시간까지)

- **명세**: todo 가 `1/1 ~ 1/5` 처럼 기간을 가질 수 있다. 시작·종료 각각 날짜 + (선택) 시간까지 설정 가능.
- **구현 핵심 (데이터 모델, 백워드 호환)**: 기존 `dueAt`(앵커 날짜 — today/이월/정렬 로직 그대로 사용) 유지 + 신규 필드 추가:
  - `endAt` (DateTime?, nullable) — 기간 모드의 종료. 단일 모드면 null.
  - `isAllDay` (bool, default false) — true 면 시간 미표시.
  - `timeAnchor` (String, default `'start'`) — 단일·시간모드에서 `dueAt` 이 '시작'인지 '마감'인지.
  - 매핑: **기간** = `dueAt`(시작) + `endAt`(종료). **단일 하루종일** = `dueAt`(date@00:00) + isAllDay=true + endAt=null. **단일 시작만** = dueAt+timeAnchor='start'. **단일 마감만** = dueAt+timeAnchor='end'.
- **영향 파일**: `lib/src/domain/todo.dart`(freezed + JSON), `lib/src/data/local/app_database.dart`(schemaVersion **4→5** + Todos 컬럼 end_at/is_all_day/time_anchor + onUpgrade), `lib/src/data/local/todos_dao.dart`, `lib/src/data/remote/supabase_todos_api.dart`(_toRow/_fromRow), `supabase/schema.sql`(ALTER todos + notify pgrst), `lib/src/features/add_todo/add_todo_sheet.dart`(날짜 섹션 UI)
- **소속**: Chain A

## Task 5: 기간이 아니면 시작/마감 시간 택일

- **명세**: 단일(비기간) 모드에서는 '하루종일' / '시작시간만' / '마감시간만' 중 하나만 택한다. 시작·마감을 동시에 못 켠다(그건 기간 모드).
- **구현 핵심**: AddTodoSheet 날짜 섹션을 **모드 선택**(하루종일 · 시작시간 · 마감시간 · 기간) 으로. 모드에 따라 picker 노출/숨김. 위 `isAllDay`/`timeAnchor`/`endAt` 로 직렬화.
- **영향 파일**: `lib/src/features/add_todo/add_todo_sheet.dart` (+ Task 4 모델)
- **소속**: Chain A

## Task 3-mapping (Q3=A): 캘린더 종류별 매핑 (Chain A 에 포함)

- **명세**: 기간 → 시작~종료 일정, 하루종일 → Google 종일 이벤트(start.date/end.date), 한쪽 시간만 → 그 시각 기준 기본 1시간 일정.
- **영향 파일**: `lib/src/features/calendar/calendar_service.dart` (이벤트 빌드 매핑만. **권한/scope 는 Task 3 담당 — 건드리지 말 것**)
- **소속**: Chain A

## Task 3: 구글 캘린더 권한 에러 (Android) 진단·수정

- **명세**: 갤S24 에서 캘린더 '권한 없음' 에러 원인 진단 후 수정. 코드 원인(요청 scope 누락, google_sign_in serverClientId/scopes, 동의 흐름)이면 고치고, 외부 원인(Google Cloud Console 동의화면에 calendar scope 미등록 / 테스트 사용자 미등록)이면 대표님이 콘솔에서 할 액션을 명확히 보고.
- **영향 파일**: `lib/src/features/calendar/google_auth_service.dart`(scope/sign-in), `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle`(필요시), `.env.local` 매핑 코드. **`calendar_service.dart` 의 이벤트 매핑은 Chain A 소관 — 건드리지 말 것.**
- **소속**: Independent (Chain A 와 파일 분리됨)

## Task 2: 카테고리 상위 '그룹' 레벨 신설

- **명세 (Q1=A)**: 카테고리들을 묶는 **그룹(큰분류)** 레벨 신설. 구조: 그룹(회사) > 카테고리(제품명) > todo 트리(태스크 > 하위, 기존 parent_id 무한 깊이). 사이드바가 그룹 단위로 접힘. 그룹 없는 카테고리는 상단 '미분류'로.
- **구현 핵심 (MVP)**:
  - 신규 `Group` freezed (id/label/colorValue/iconCodePoint?/sortOrder/isBuiltin/createdAt). `Category` 에 `groupId`(String?, nullable) 추가.
  - Drift `Groups` 테이블 + `Categories.groupId` 컬럼, schemaVersion **5→6** (Chain A 의 5 다음). onUpgrade ALTER + PRAGMA 가드.
  - Supabase `groups` 테이블 + RLS + publication + `categories.group_id` ALTER, `notify pgrst`.
  - `groups_dao` / `supabase_groups_api` / groups repository(+outbox kind `grp-upsert`/`grp-delete`) / `groups_controller` + `groupsProvider`.
  - 사이드바(app_shell.dart): 그룹 → 그 그룹의 카테고리 렌더(접힘) + 미분류 카테고리. '그룹 추가'(AddGroupDialog, label+색) + 카테고리 우클릭/long-press 메뉴에 '그룹 이동'.
- **영향 파일**: `lib/src/domain/category.dart`, `lib/src/domain/group.dart`(신규), `lib/src/data/local/app_database.dart`, `lib/src/data/local/categories_dao.dart`, `lib/src/data/local/groups_dao.dart`(신규), `lib/src/data/remote/supabase_groups_api.dart`(신규), `lib/src/data/syncing_groups_repository.dart`(신규), `lib/src/features/category/groups_controller.dart`(신규) + add_group_dialog, `lib/src/ui/app_shell.dart`, `supabase/schema.sql`
- **소속**: Wave 2 (Chain A 의 schemaVersion 5 + schema.sql 변경에 의존 → 직렬)

---

## 병렬화 계획 (DAG)

shared 파일이 **`app_database.dart`(schemaVersion 단일 라인 + 마이그레이션 case) 와 `supabase/schema.sql`** 이라 schema 를 만지는 task 는 직렬화한다. freezed/drift codegen 도 생성파일 충돌 위험이 있어 격리.

- **Wave 1 (병렬, worktree 격리)**:
  - **Chain A** = Task 4 → 5 → 1 → 캘린더 매핑. (한 에이전트 순차) — todo 모델/AddTodoSheet/date_format/todo_tile/calendar_service mapping/schema.sql(todos)/app_database(v5). 다중 commit.
  - **Task 3** = Android 캘린더 권한. (독립 에이전트) — google_auth_service/AndroidManifest/gradle. Chain A 와 파일 disjoint.
- **머지**: Wave 1 두 브랜치를 main 으로 병합 + `make check` green 확인.
- **Wave 2 (단독)**: **Task 2** = 그룹 레벨. main(=Chain A 의 v5 반영) 위에서 schemaVersion 5→6.

각 에이전트는 `make codegen`(모델 변경 시) + `make check`(analyze+format+test) **green 확인 후에만 commit**. 실패 시 commit 금지하고 보고. 대표님 라이브 `solo_todo.sqlite` / `~/solo_todo_db_backup/` 는 절대 건드리지 않는다.
