import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

@DriftDatabase(tables: [Todos], daos: [TodosDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDisk());

  /// In-memory 인스턴스 — 테스트 / 일회성 환경 용.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openOnDisk() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'solo_todo.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
