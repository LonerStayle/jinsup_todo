import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/todo_repository.dart';
import '../../domain/todo.dart';
import '../calendar/calendar_service.dart';
import 'add_todo_sheet.dart';

/// AddTodoSheet 가 만든 [AddTodoSubmission] 을 도메인 [Todo] 로 변환 + 저장 + (선택) Calendar 등록.
class AddTodoController {
  AddTodoController({
    required this.repo,
    required this.now,
    required this.calendar,
  });

  final TodoRepository repo;
  final DateTime Function() now;

  /// null 이면 Google OAuth 미설정 → addToCalendar 가 true 여도 자동 skip.
  final CalendarService? calendar;

  /// 1) Todo.create 으로 새 todo 생성 + repo.upsert
  /// 2) addToCalendar && dueAt != null && calendar != null 이면 Calendar 이벤트 생성 후
  ///    eventId 를 todo 에 붙여서 다시 upsert
  /// Calendar 호출 실패는 fatal X — todo 자체는 보존.
  Future<Todo> add(AddTodoSubmission s) async {
    var todo = Todo.create(
      title: s.title,
      category: s.category,
      dueAt: s.dueAt,
      now: now,
    );
    await repo.upsert(todo);

    if (s.addToCalendar && s.dueAt != null && calendar != null) {
      try {
        final eventId = await calendar!.createEventForTodo(
          todo,
          isAllDay: s.isAllDay,
        );
        if (eventId != null) {
          todo = todo.withCalendarEvent(eventId, now: now);
          await repo.upsert(todo);
        }
      } catch (e) {
        debugPrint('[solo_todo] Calendar 이벤트 생성 실패: $e');
      }
    }
    return todo;
  }
}

final addTodoControllerProvider = Provider<AddTodoController>(
  (ref) => AddTodoController(
    repo: ref.watch(todoRepositoryProvider),
    now: ref.watch(nowProvider),
    calendar: ref.watch(calendarServiceProvider),
  ),
);
