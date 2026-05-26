import '../../domain/category.dart';
import '../../domain/todo.dart';
import '../todo_repository.dart';
import 'todos_dao.dart';

/// [TodoRepository] 의 Drift (SQLite) 구현. offline-first 1차 출처.
///
/// remote sync 책임은 별도 어댑터 (`RemoteTodoRepository`) 와 합성 어댑터
/// (`SyncingTodoRepository`, phase 7) 가 맡는다.
class LocalTodoRepository implements TodoRepository {
  LocalTodoRepository(this._dao);

  final TodosDao _dao;

  @override
  Future<Todo?> getById(String id) => _dao.getById(id);

  @override
  Stream<List<Todo>> watchAll() => _dao.watchAll();

  @override
  Stream<List<Todo>> watchByCategory(Category category) =>
      _dao.watchByCategory(category);

  @override
  Stream<List<Todo>> watchToday(DateTime Function() now) =>
      _dao.watchToday(now);

  @override
  Future<void> upsert(Todo todo) => _dao.upsert(todo);

  @override
  Future<void> deleteById(String id) => _dao.deleteById(id);
}
