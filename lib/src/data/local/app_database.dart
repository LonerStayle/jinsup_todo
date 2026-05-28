import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

@DriftDatabase(tables: [Todos, OutboxEntries], daos: [TodosDao, OutboxDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDisk());

  /// In-memory 인스턴스 — 테스트 / 일회성 환경 용.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  /// `storeDateTimeAsText: true` — DateTime 을 ISO 8601 text 로 저장.
  /// 기본 (unix int) 은 fetch 시 항상 local time 으로 변환되어 UTC↔local 구분을 잃는다.
  /// UTC 를 보존해야 Supabase 동기화 시 timezone 충돌이 없다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// 향후 schema 변경 (컬럼 추가, 인덱스, 새 테이블) 시 [onUpgrade] case 만 추가.
  ///
  /// 예시 ─ priority 컬럼 도입 시:
  /// ```dart
  /// onUpgrade: (m, from, to) async {
  ///   if (from < 2) {
  ///     await m.addColumn(todos, todos.priority);
  ///   }
  /// }
  /// ```
  ///
  /// 처음부터 비어 있어도 골격을 두면 `schemaVersion` 만 올리고 case 추가하면 끝.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // schemaVersion 1 → ? : case 별 마이그레이션 추가. 현재 1 → 1 이라 no-op.
    },
  );

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
