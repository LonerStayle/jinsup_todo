import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/category.dart' as domain;
import 'outbox_dao.dart';
import 'todos_dao.dart';

part 'app_database.g.dart';

/// `todos` SQLite 테이블.
///
/// Drift 의 row 데이터 클래스는 도메인 [Todo] 와 충돌하지 않도록 `TodoRow` 로 강제.
/// 매핑은 [TodosDao] 가 담당한다.
@DataClassName('TodoRow')
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  // Category.id (snake_case, e.g. 'personal_dev') 저장. enum 명 직접 저장 X.
  TextColumn get category => text()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get calendarEventId => text().nullable()();
  // v1.1 — 트리 노드 부모 id. null = 카테고리 직속 root.
  // FK 제약은 두지 않음 — Supabase 양방향 동기화 도중 일시적 dangling 가능 + LWW 가 자정 처리.
  TextColumn get parentId => text().nullable()();
  // v1.1 — TodoType.name ('task' | 'note'). 기본 'task'.
  TextColumn get type => text().withDefault(const Constant('task'))();
  // v1.1 — 같은 parent 내 사용자 정의 순서. 작은 값 먼저. drag-reorder 는 v1.2 후속.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// v1.2 — 카테고리 테이블. 5 builtin 도 row 로 저장되어 사용자가 추가 / 삭제 가능.
///
/// id 는 사용자 카테고리는 uuid, builtin 은 'work' / 'personal_dev' / 'daily' /
/// 'longterm' / 'idea' 로 유지 (옛 todos.category id 와 호환).
///
/// 정렬은 (sortOrder asc, createdAt asc) — 같은 sortOrder 면 먼저 만든 게 위.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  // Material Icons 폰트의 codepoint. Color.value 와 함께 row 직접 저장 — UI 가
  // category.icon / category.color getter 로 IconData / Color 재구성.
  IntColumn get iconCodePoint => integer()();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 오프라인/연결 실패 시 원격 push 대기열. FIFO 로 순서 보존.
/// [SyncingTodoRepository] 가 local mutation 후 enqueue, 재연결 시 _tryFlush 가 비움.
@DataClassName('OutboxRow')
class OutboxEntries extends Table {
  TextColumn get id => text()(); // outbox entry id (uuid)
  // 'upsert' | 'delete'
  TextColumn get kind => text()();
  // 대상 todo id (delete 시에도 식별용)
  TextColumn get todoId => text()();
  // upsert 일 때만 — Todo JSON (jsonEncode). delete 일 때 null.
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Todos, Categories, OutboxEntries],
  daos: [TodosDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDisk());

  /// In-memory 인스턴스 — 테스트 / 일회성 환경 용.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  /// `storeDateTimeAsText: true` — DateTime 을 ISO 8601 text 로 저장.
  /// 기본 (unix int) 은 fetch 시 항상 local time 으로 변환되어 UTC↔local 구분을 잃는다.
  /// UTC 를 보존해야 Supabase 동기화 시 timezone 충돌이 없다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// schemaVersion 변경 history:
  /// - v1: 초기 (todos + outboxEntries)
  /// - v2: todos 에 parent_id / type / sort_order 컬럼 추가 (v1.1 — 트리 / 메모)
  /// - v3: categories 테이블 신규 + 5 builtin seed (v1.2 — 카테고리 fully 동적).
  ///   `todos.description` 컬럼 ALTER 는 v1.2 의 description task 가 이 case 에
  ///   `m.addColumn(todos, todos.description)` 를 추가해 채운다.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // 신규 DB — 5 builtin 카테고리 seed.
      await _seedBuiltinCategories();
    },
    onUpgrade: (m, from, to) async {
      // 1 → 2: v1.1 트리 / 메모 모델용 3 컬럼 추가.
      // withDefault('task') / withDefault(0) 가 ALTER TABLE 시 자동 적용 (Drift) —
      // 기존 row 도 type='task' / sort_order=0 으로 채워진다. parent_id 는 nullable
      // 이므로 NULL 로 채워짐. RLS / Supabase 별도 migration 은 schema.sql 의 ALTER 안내.
      if (from < 2) {
        await m.addColumn(todos, todos.parentId);
        await m.addColumn(todos, todos.type);
        await m.addColumn(todos, todos.sortOrder);
      }
      // 2 → 3: categories 테이블 신규 + 5 builtin seed.
      if (from < 3) {
        await m.createTable(categories);
        await _seedBuiltinCategories();
      }
    },
  );

  /// 5 builtin 카테고리를 categories 에 seed.
  /// [InsertMode.insertOrIgnore] — 이미 같은 id 가 있으면 무시 (사용자가 builtin 을
  /// 삭제했다가 다른 디바이스에서 다시 migrate 가 일어나도 conflict 없이 idempotent).
  /// createdAt 은 epoch 0 으로 통일 — sortOrder asc 우선이므로 정렬 영향 없음.
  Future<void> _seedBuiltinCategories() async {
    final seedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    for (final c in domain.Category.builtinSeeds) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: c.id,
          label: c.label,
          iconCodePoint: c.iconCodePoint,
          colorValue: c.colorValue,
          sortOrder: Value(c.sortOrder),
          isBuiltin: Value(c.isBuiltin),
          createdAt: seedAt,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  static QueryExecutor _openOnDisk() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'solo_todo.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  /// 사용자 데이터 전체 삭제 (todos + outbox). signOut 또는 다른 user 로 전환 시 호출.
  /// 단일 사용자 비전이지만, sign-out 후 다른 이메일로 로그인 시 옛 데이터 노출 방지.
  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(todos).go();
      await delete(outboxEntries).go();
    });
  }
}
