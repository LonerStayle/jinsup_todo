# 중첩 체크리스트 + 모바일 관리 + 정렬 + 전체보기 분리 — 배치 (4 task)

> 대표님 확정: A OK / B OK / C OK / Q1 OK / Q2 OK / Q3 OK.
> **DB 스키마 변경 없음** (sortOrder·parent_id 는 v1.1 부터 존재). 마이그레이션 불필요.
> main 에서 **순차 실행** (BC → A → D), 각 에이전트가 `make check` green 후 commit.

---

## Task C: 하위 체크리스트 (자식 todo) 생성 + 중첩 표시

- 각 할 일에 **'＋ 하위 추가'** 액션 → `AddTodoSheet` 가 그 항목을 부모로 자식 생성 (parentId + 부모의 category 상속). 무한 깊이.
- 오늘/카테고리 목록을 **들여쓰기 중첩(접힘 가능)** 으로 표시 (전체보기처럼). 기존 breadcrumb 평면 → 트리.
- 영향: `add_todo_sheet.dart`(parentId), `todo_tile.dart`/`dismissible_todo_tile.dart`('하위 추가'), `animated_todo_list.dart`(중첩 렌더), `home_screen.dart`, `category_view.dart`, (read-only) `tree_providers.dart`.

## Task B: 정렬 — 기본 최신순 + 드래그 순서변경

- 토글 없음. **기본 = 최신순** (`sortOrder asc, updatedAt desc`). 모든 목록.
- 불변식: **작은 sortOrder = 위**. 신규 생성·시트 수정 → `sortOrder = min(형제)-1` (맨 위). 드래그 → 형제 집합 재인덱싱. **toggle(체크)는 sortOrder 불변**(체크해도 자리 안 바뀜).
- 오늘 화면: 기존 '미체크 먼저' 유지 → 그 안에서 위 규칙.
- 영향: `todos_dao.dart`(orderBy), `todo_actions_controller.dart`(reorder + bumpToTop), 생성 경로(`add_todo_controller`/repo), 리스트 위젯(드래그).
- **소속**: Task C 와 한 에이전트(BC 체인). 리스트 렌더를 공동 재정의하므로 분리 불가. C(중첩) 먼저, B(정렬/드래그) 위에 얹기. 증분 commit.

## Task A: 모바일 그룹/카테고리 관리 (드로우어) + 그룹 이동 편의

- 모바일 상단 앱바에 **⚙/☰ '관리'** → **Drawer** 로 그룹/카테고리 관리: 그룹/카테고리 **추가·삭제·이동** (데스크탑 사이드바와 동일 기능). 기존 컨트롤러/다이얼로그 재사용.
- **E.** 드로우어에서 **카테고리를 드래그해 다른 그룹으로 이동** (ReorderableList / 드래그 타겟 → `categoriesController.moveToGroup`). 그룹 헤더 위로 드롭하면 그 그룹으로.
- **F.** 카테고리마다 **소속 그룹 표시** (드로우어 + 데스크탑 사이드바 모두 — 그룹명/색 chip 또는 들여쓰기). 미분류는 '미분류' 라벨.
- 영향: `app_shell.dart`(모바일 앱바 + Drawer), 신규 `features/manage/manage_screen.dart`(또는 drawer 위젯), (재사용) categories/groups controller + AddCategory/AddGroup dialog.
- **소속**: 독립. BC 와 파일 disjoint (app_shell vs 리스트 화면들).

## Task D: 전체보기 [체크리스트]/[메모] 탭 분리

- 전체보기 상단 **탭** — 체크리스트(task 트리만) / 메모(note 만). Q3 OK.
- 영향: `outline_screen.dart`(탭), `tree_providers.dart`(note-only / task-only root provider 추가).
- **소속**: 독립. tree_providers 는 D 가 소유(추가), BC 는 read-only.

---

## DAG (순차 — stale-base 회피)

1. **BC** (Task C → Task B) — 중첩 + 자식추가, 그 위에 최신순 정렬 + 드래그.
2. **A** — 모바일 관리 화면.
3. **D** — 전체보기 탭 분리.

각 단계 `make check`(analyze+format+test) green 후 commit. 라이브 DB/백업 미접촉.
