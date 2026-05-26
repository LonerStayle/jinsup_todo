import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/todo_repository.dart';
import '../../domain/todo.dart';
import 'add_todo_sheet.dart';

/// AddTodoSheet 가 만든 [AddTodoSubmission] 을 도메인 [Todo] 로 변환 + 저장.
///
/// Calendar 등록 (s.addToCalendar) 은 phase 8 의 CalendarService 가 연결한다.
class AddTodoController {
  AddTodoController(this._repo, this._now);

  final TodoRepository _repo;
  final DateTime Function() _now;

  Future<Todo> add(AddTodoSubmission s) async {
    final todo = Todo.create(
      title: s.title,
      category: s.category,
      dueAt: s.dueAt,
      now: _now,
    );
    await _repo.upsert(todo);
    return todo;
  }
}

final addTodoControllerProvider = Provider<AddTodoController>(
  (ref) => AddTodoController(
    ref.watch(todoRepositoryProvider),
    ref.watch(nowProvider),
  ),
);
