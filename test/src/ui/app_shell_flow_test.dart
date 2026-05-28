import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_controller.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';
import 'package:solo_todo/src/features/todo_actions/todo_actions_controller.dart';

/// **사용자 사이클 통합 흐름** (sign-in 후) — 추가 → 체크 → 삭제 → undo 가 DB 까지
/// 일관되게 반영되는지 검증.
///
/// AppShell widget mount 는 hotkey/tray/realtime sync 등 platform 의존성과
/// currentDayProvider 의 Timer 가 cleanup 보장이 까다로워, controller + DB 레벨로 검증.
/// UI 갱신은 별도 home_screen_test 의 stream-based 검증으로 cover.
void main() {
  test('추가 → 체크 → 삭제 → undo 사이클 (controller + DB 일관성)', () async {
    final db = AppDatabase.memory();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 5, 27, 10)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // 1) 추가.
    final addResult = await container
        .read(addTodoControllerProvider)
        .add(
          const AddTodoSubmission(
            title: '통합 테스트 todo',
            category: Category.work,
            dueAt: null,
            addToCalendar: false,
          ),
        );
    final created = addResult.todo;
    expect(addResult.calendarWarning, isNull);
    expect(await db.todosDao.getById(created.id), isNotNull);

    // 2) 체크.
    await container.read(todoActionsProvider).toggle(created);
    final afterToggle = await db.todosDao.getById(created.id);
    expect(afterToggle!.isDone, isTrue, reason: 'toggle 후 doneAt 가 set 되어야 함');

    // 3) 삭제.
    await container.read(todoActionsProvider).delete(afterToggle);
    expect(await db.todosDao.getById(created.id), isNull);

    // 4) undo (restore).
    await container.read(todoActionsProvider).restore(afterToggle);
    final restored = await db.todosDao.getById(created.id);
    expect(restored, isNotNull);
    expect(restored!.title, '통합 테스트 todo');
    // 체크/삭제 모두 거친 상태 그대로 복원되는지 — restore 는 마지막 상태 (체크된 상태) 보존.
    expect(restored.isDone, isTrue);
  });

  test('AddTodoController calendarWarning — Google OAuth 미설정 시 안내', () async {
    final db = AppDatabase.memory();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 5, 27, 10)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final result = await container
        .read(addTodoControllerProvider)
        .add(
          AddTodoSubmission(
            title: '캘린더 토글 ON',
            category: Category.work,
            dueAt: DateTime(2026, 5, 28, 14),
            addToCalendar: true,
          ),
        );

    // todo 자체는 저장.
    expect(await db.todosDao.getById(result.todo.id), isNotNull);
    // OAuth 미설정 → warning 노출.
    expect(result.calendarWarning, isNotNull);
  });
}
