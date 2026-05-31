import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/todo.dart';

/// schemaVersion 6 → 7 migration 검증 (date-repeat).
///
/// 시나리오:
///   1. raw sqlite3 in-memory 에 v6 시점 schema (todos 15 컬럼 + categories + groups +
///      outbox_entries) 만들고 옛 todos row 한 건을 직접 insert. user_version = 6.
///   2. 같은 connection 을 AppDatabase 로 wrap → onUpgrade(6, 7) 발화 → todos 에
///      series_id / recurrence_rule / recurrence_end_at / is_series_master ALTER.
///   3. 옛 row 보존 + 신규 컬럼 기본값(series 계열 null, is_series_master=false) 확인.
///   4. migrate 후 마스터 + 인스턴스 round-trip 확인.
void main() {
  void seedV6Schema(sqlite.Database db) {
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
        "description" TEXT NULL,
        "end_at" TEXT NULL,
        "is_all_day" INTEGER NOT NULL DEFAULT 0,
        "time_anchor" TEXT NOT NULL DEFAULT 'start',
        PRIMARY KEY ("id")
      );
    ''');
    db.execute('''
      CREATE TABLE "categories" (
        "id" TEXT NOT NULL,
        "label" TEXT NOT NULL,
        "icon_code_point" INTEGER NOT NULL,
        "color_value" INTEGER NOT NULL,
        "sort_order" INTEGER NOT NULL DEFAULT 0,
        "is_builtin" INTEGER NOT NULL DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "group_id" TEXT NULL,
        PRIMARY KEY ("id")
      );
    ''');
    db.execute('''
      CREATE TABLE "groups" (
        "id" TEXT NOT NULL,
        "label" TEXT NOT NULL,
        "color_value" INTEGER NOT NULL,
        "sort_order" INTEGER NOT NULL DEFAULT 0,
        "is_builtin" INTEGER NOT NULL DEFAULT 0,
        "created_at" TEXT NOT NULL,
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
    db.execute('PRAGMA user_version = 6');
  }

  test('v6 fixture → migrate → 옛 row 보존 + 반복 컬럼 기본값', () async {
    final db = sqlite.sqlite3.openInMemory();
    addTearDown(db.close);
    seedV6Schema(db);

    db.execute('''
      INSERT INTO "todos" (id, title, category, due_at, done_at, created_at, updated_at, calendar_event_id, parent_id, type, sort_order, description, end_at, is_all_day, time_anchor)
      VALUES (
        'v6-task', '옛 회사 todo', 'work',
        '2026-05-30T09:00:00.000Z', NULL,
        '2026-05-30T08:00:00.000Z', '2026-05-30T08:00:00.000Z',
        NULL, NULL, 'task', 0, NULL, NULL, 0, 'start'
      );
    ''');

    final app = AppDatabase(NativeDatabase.opened(db));
    addTearDown(app.close);

    // 첫 query 가 migration 트리거 + 옛 데이터 보존.
    final t = await app.todosDao.getById('v6-task');
    expect(t, isNotNull);
    expect(t!.title, '옛 회사 todo');
    expect(t.category, Category.work);
    expect(t.dueAt, DateTime.utc(2026, 5, 30, 9, 0));
    // 신규 반복 컬럼 기본값.
    expect(t.seriesId, isNull);
    expect(t.recurrenceRule, isNull);
    expect(t.recurrenceEndAt, isNull);
    expect(t.isSeriesMaster, isFalse);

    // 4 컬럼이 실제로 추가됐는지 raw 검증.
    final cols = db.select('PRAGMA table_info("todos");');
    final names = cols.map((r) => r['name'] as String).toSet();
    expect(
      names,
      containsAll([
        'series_id',
        'recurrence_rule',
        'recurrence_end_at',
        'is_series_master',
      ]),
      reason: 'onUpgrade 6→7 가 반복 4 컬럼을 추가해야 함',
    );

    final version = db.select('PRAGMA user_version;').first['user_version'];
    expect(version, greaterThanOrEqualTo(7));
  });

  test('migrate 후 마스터 + 인스턴스 round-trip', () async {
    final db = sqlite.sqlite3.openInMemory();
    addTearDown(db.close);
    seedV6Schema(db);

    final app = AppDatabase(NativeDatabase.opened(db));
    addTearDown(app.close);

    final rule = const RecurrenceRule(freq: RecurrenceFreq.monthly);
    final master = Todo(
      id: 'master-1',
      title: '매월 1일 정산',
      category: Category.work,
      dueAt: DateTime.utc(2026, 6, 1, 9),
      doneAt: null,
      createdAt: DateTime.utc(2026, 5, 31),
      updatedAt: DateTime.utc(2026, 5, 31),
      seriesId: 'master-1',
      recurrenceRule: rule.encode(),
      recurrenceEndAt: DateTime.utc(2026, 12, 31),
      isSeriesMaster: true,
    );
    final instance = Todo(
      id: 'inst-1',
      title: '매월 1일 정산',
      category: Category.work,
      dueAt: DateTime.utc(2026, 6, 1, 9),
      doneAt: null,
      createdAt: DateTime.utc(2026, 6, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
      seriesId: 'master-1',
    );
    await app.todosDao.upsert(master);
    await app.todosDao.upsert(instance);

    final m = await app.todosDao.getById('master-1');
    expect(m!.isSeriesMaster, isTrue);
    expect(m.isRecurringMaster, isTrue);
    expect(m.recurrence, rule);
    expect(m.recurrenceEndAt, DateTime.utc(2026, 12, 31));
    expect(m.seriesId, 'master-1');

    final i = await app.todosDao.getById('inst-1');
    expect(i!.isSeriesMaster, isFalse);
    expect(i.seriesId, 'master-1');
    expect(i.recurrenceRule, isNull);
  });
}
