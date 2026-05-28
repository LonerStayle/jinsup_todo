import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

/// schemaVersion 1 → 2 migration 검증.
///
/// 시나리오:
///   1. raw sqlite3 in-memory 에 v1 시점 schema (todos + outbox_entries) 만 만들고
///      옛 row 를 직접 insert. PRAGMA user_version = 1 으로 Drift 에 v1 알림.
///   2. 같은 sqlite connection 을 AppDatabase 로 wrap (NativeDatabase.opened).
///   3. AppDatabase 의 schemaVersion 2 와 비교 → MigrationStrategy.onUpgrade(1, 2) 발화
///      → m.addColumn x3 (parent_id / type / sort_order) 실행.
///   4. 옛 row 가 보존되고 신규 컬럼이 기본값 (type='task', sort_order=0,
///      parent_id=null) 으로 채워졌는지 확인.
void main() {
  void seedV1Schema(sqlite.Database db) {
    db.execute('''
      CREATE TABLE "todos" (
        "id" TEXT NOT NULL,
        "title" TEXT NOT NULL,
        "category" TEXT NOT NULL,
        "due_at" TEXT NULL,
        "done_at" TEXT NULL,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "calendar_event_id" TEXT NULL,
        PRIMARY KEY ("id")
      );
    ''');
    db.execute('''
      CREATE TABLE "outbox_entries" (
        "id" TEXT NOT NULL,
        "kind" TEXT NOT NULL,
        "todo_id" TEXT NOT NULL,
        "payload" TEXT NULL,
        "created_at" TEXT NOT NULL,
        PRIMARY KEY ("id")
      );
    ''');
    db.execute('PRAGMA user_version = 1');
  }

  test('v1 fixture → migrate → 옛 데이터 보존 + 신규 컬럼 기본값', () async {
    final db = sqlite.sqlite3.openInMemory();
    addTearDown(db.close);

    seedV1Schema(db);

    // v1 row 직접 insert — 옛 사용자 데이터를 흉내.
    db.execute('''
      INSERT INTO "todos" (id, title, category, due_at, done_at, created_at, updated_at, calendar_event_id)
      VALUES (
        'legacy-1',
        '옛 회사 todo',
        'work',
        '2026-05-26T09:00:00.000Z',
        NULL,
        '2026-05-26T08:00:00.000Z',
        '2026-05-26T08:00:00.000Z',
        NULL
      );
    ''');
    db.execute('''
      INSERT INTO "todos" (id, title, category, due_at, done_at, created_at, updated_at, calendar_event_id)
      VALUES (
        'legacy-2',
        '옛 체크된 일상',
        'daily',
        NULL,
        '2026-05-25T20:00:00.000Z',
        '2026-05-25T09:00:00.000Z',
        '2026-05-25T20:00:00.000Z',
        'cal-evt-xyz'
      );
    ''');

    // AppDatabase 로 wrap → schemaVersion 2 비교 후 onUpgrade(1, 2) 발화.
    // Drift 의 connection 은 lazy 라 첫 query 시점에 migration 이 실행된다.
    // pragma 검증 전에 row 한 번 읽어서 migration 강제.
    final app = AppDatabase(NativeDatabase.opened(db));
    addTearDown(app.close);

    // 옛 row 데이터 보존 + 신규 컬럼 기본값 (이 query 가 migration 을 트리거).
    final t1 = await app.todosDao.getById('legacy-1');
    expect(t1, isNotNull);
    expect(t1!.title, '옛 회사 todo');
    expect(t1.category, Category.work);
    expect(t1.dueAt, DateTime.utc(2026, 5, 26, 9, 0));
    expect(t1.doneAt, isNull);
    expect(t1.type, TodoType.task, reason: 'withDefault 가 ALTER 시 적용');
    expect(t1.sortOrder, 0);
    expect(t1.parentId, isNull);

    final t2 = await app.todosDao.getById('legacy-2');
    expect(t2, isNotNull);
    expect(t2!.title, '옛 체크된 일상');
    expect(t2.category, Category.daily);
    expect(t2.doneAt, DateTime.utc(2026, 5, 25, 20, 0));
    expect(t2.calendarEventId, 'cal-evt-xyz');
    expect(t2.type, TodoType.task);
    expect(t2.sortOrder, 0);
    expect(t2.parentId, isNull);

    // 신규 컬럼이 실제로 추가됐는지 raw 검증.
    final cols = db.select('PRAGMA table_info("todos");');
    final colNames = cols.map((r) => r['name'] as String).toSet();
    expect(
      colNames,
      containsAll(['parent_id', 'type', 'sort_order']),
      reason: 'onUpgrade 1→2 가 세 컬럼을 추가해야 함',
    );

    // user_version 도 최소 2 이상으로 갱신됐어야 한다 (현재 schemaVersion 따라).
    // v1.2 부터 schemaVersion 3 이지만 이 테스트의 핵심은 1→2 컬럼 추가 검증.
    final version = db.select('PRAGMA user_version;').first['user_version'];
    expect(
      version,
      greaterThanOrEqualTo(2),
      reason: '최소 v2 까지 migrate 됐어야 함',
    );
  });

  test(
    'migrate 후 신규 v2 row insert/read — parent_id/type/sortOrder 정상 동작',
    () async {
      final db = sqlite.sqlite3.openInMemory();
      addTearDown(db.close);

      seedV1Schema(db);

      final app = AppDatabase(NativeDatabase.opened(db));
      addTearDown(app.close);

      // migrate 후 신규 row — 트리 노드 + note.
      final note = Todo(
        id: 'new-note',
        title: '→ 새 메모',
        category: Category.work,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 28),
        updatedAt: DateTime.utc(2026, 5, 28),
        calendarEventId: null,
        parentId: 'project-x',
        type: TodoType.note,
        sortOrder: 3,
      );
      await app.todosDao.upsert(note);

      final got = await app.todosDao.getById('new-note');
      expect(got!.parentId, 'project-x');
      expect(got.type, TodoType.note);
      expect(got.sortOrder, 3);
    },
  );
}
