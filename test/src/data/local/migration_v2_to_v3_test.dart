import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

/// schemaVersion 2 → 3 migration 검증.
///
/// 시나리오:
///   1. raw sqlite3 in-memory 에 v2 시점 schema (todos 8 컬럼 + outbox_entries) 만들고
///      옛 todos row 두 건 (parent_id/type/sort_order 포함) 을 직접 insert.
///      PRAGMA user_version = 2 로 Drift 에 v2 알림.
///   2. 같은 sqlite connection 을 AppDatabase 로 wrap.
///   3. AppDatabase 의 schemaVersion 3 와 비교 → onUpgrade(2, 3) 발화 →
///      createTable(categories) + _seedBuiltinCategories.
///   4. categories 5건 seed 확인 + 기존 todos row 보존 확인.
///
/// `todos.description` ALTER 검증은 v1.2 의 description task 에서 같은 case 가
/// 채워진 뒤 별도 추가한다 (현 단계에선 categories seed 만 검증).
void main() {
  void seedV2Schema(sqlite.Database db) {
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
        "parent_id" TEXT NULL,
        "type" TEXT NOT NULL DEFAULT 'task',
        "sort_order" INTEGER NOT NULL DEFAULT 0,
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
    db.execute('PRAGMA user_version = 2');
  }

  test('v2 fixture → migrate → categories 5건 seed + todos row 보존', () async {
    final db = sqlite.sqlite3.openInMemory();
    addTearDown(db.close);

    seedV2Schema(db);

    // v2 row 두 건 — root task + child note.
    db.execute('''
      INSERT INTO "todos" (id, title, category, due_at, done_at, created_at, updated_at, calendar_event_id, parent_id, type, sort_order)
      VALUES (
        'v2-root',
        '프로젝트 X',
        'work',
        NULL,
        NULL,
        '2026-05-27T09:00:00.000Z',
        '2026-05-27T09:00:00.000Z',
        NULL,
        NULL,
        'task',
        0
      );
    ''');
    db.execute('''
      INSERT INTO "todos" (id, title, category, due_at, done_at, created_at, updated_at, calendar_event_id, parent_id, type, sort_order)
      VALUES (
        'v2-note',
        '→ KV 캐싱 도입 검토',
        'work',
        NULL,
        NULL,
        '2026-05-27T09:30:00.000Z',
        '2026-05-27T09:30:00.000Z',
        NULL,
        'v2-root',
        'note',
        1
      );
    ''');

    // AppDatabase wrap → schemaVersion 3 비교 후 onUpgrade(2, 3) 발화.
    // Drift connection lazy — 첫 query 시점에 migration 실행.
    final app = AppDatabase(NativeDatabase.opened(db));
    addTearDown(app.close);

    // 옛 v2 todos row 보존.
    final root = await app.todosDao.getById('v2-root');
    expect(root, isNotNull);
    expect(root!.title, '프로젝트 X');
    expect(root.category, Category.work);
    expect(root.parentId, isNull);
    expect(root.type, TodoType.task);
    expect(root.sortOrder, 0);

    final note = await app.todosDao.getById('v2-note');
    expect(note, isNotNull);
    expect(note!.title, '→ KV 캐싱 도입 검토');
    expect(note.parentId, 'v2-root');
    expect(note.type, TodoType.note);
    expect(note.sortOrder, 1);

    // categories 테이블이 생성됐는지 raw 검증.
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='categories';",
    );
    expect(tables.length, 1, reason: 'categories 테이블이 생성돼야 함');

    // 5 builtin seed 확인.
    final rows = db.select(
      'SELECT id, label, icon_code_point, color_value, sort_order, is_builtin FROM "categories" ORDER BY sort_order ASC;',
    );
    expect(rows.length, 5, reason: 'builtin 5종 seed 됐어야 함');

    final ids = rows.map((r) => r['id'] as String).toList();
    expect(ids, ['work', 'personal_dev', 'daily', 'longterm', 'idea']);

    // sort_order 0..4 + is_builtin = 1 검증.
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final seed = Category.builtinSeeds[i];
      expect(r['sort_order'], i);
      expect(r['is_builtin'], 1, reason: 'builtin 으로 표시');
      expect(r['label'], seed.label);
      expect(r['icon_code_point'], seed.iconCodePoint);
      expect(r['color_value'], seed.colorValue);
    }

    // user_version 도 3 으로 갱신.
    final version = db.select('PRAGMA user_version;').first['user_version'];
    expect(version, greaterThanOrEqualTo(3), reason: '최소 v3 까지 migrate 됐어야 함');
  });

  test(
    'InsertMode.insertOrIgnore — 같은 onUpgrade 가 중복 호출돼도 seed 5건 유지',
    () async {
      // 같은 AppDatabase 인스턴스에서 _seedBuiltinCategories 가 한 번 호출되어
      // 5건이 들어간 뒤에도, 같은 id 로 insert 가 시도되면 insertOrIgnore 로 skip.
      // (실제 production 에서는 onUpgrade(2, 3) 가 한 번만 호출되므로 이 path 는 안 타지만,
      //  insertOrIgnore 정책 자체가 회귀하지 않도록 보장.)
      final app = AppDatabase.memory();
      addTearDown(app.close);

      // 첫 query → onCreate 트리거 → 5건 seed.
      final before = await app.select(app.categories).get();
      expect(before.length, 5);

      // 같은 id 로 다시 insertOrIgnore 시도 — skip.
      for (final c in Category.builtinSeeds) {
        await app
            .into(app.categories)
            .insert(
              CategoriesCompanion.insert(
                id: c.id,
                label: c.label,
                iconCodePoint: c.iconCodePoint,
                colorValue: c.colorValue,
                sortOrder: Value(c.sortOrder),
                isBuiltin: Value(c.isBuiltin),
                createdAt: DateTime.utc(2026),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final after = await app.select(app.categories).get();
      expect(after.length, 5, reason: 'insertOrIgnore — 중복 insert 무시');
    },
  );
}
