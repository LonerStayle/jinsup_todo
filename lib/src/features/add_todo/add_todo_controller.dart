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
  /// Calendar 호출 실패는 fatal X — todo 자체는 보존. UI 에 안내할 warning 메시지를
  /// 결과에 포함해 반환.
  Future<AddTodoResult> add(AddTodoSubmission s) async {
    var todo = Todo.create(
      title: s.title,
      category: s.category,
      dueAt: s.dueAt,
      now: now,
      type: s.type,
      description: s.description,
      endAt: s.endAt,
      isAllDay: s.isAllDay,
      timeAnchor: s.timeAnchor,
    );
    await repo.upsert(todo);

    String? warning;
    if (s.addToCalendar && s.dueAt != null) {
      if (calendar == null) {
        warning = 'Google Calendar 연동이 설정되지 않아 등록을 건너뛰었어요.';
      } else {
        try {
          final eventId = await calendar!.createEventForTodo(
            todo,
            isAllDay: s.isAllDay,
          );
          if (eventId != null) {
            todo = todo.withCalendarEvent(eventId, now: now);
            await repo.upsert(todo);
          } else {
            warning = 'Google Calendar 권한이 거부됐어요. 등록을 건너뛰었어요.';
          }
        } catch (e) {
          debugPrint('[solo_todo] Calendar 이벤트 생성 실패: $e');
          warning = 'Google Calendar 등록에 실패했어요. (권한 또는 네트워크 확인)';
        }
      }
    }
    return AddTodoResult(todo: todo, calendarWarning: warning);
  }
}

/// [AddTodoController.add] 의 결과. UI 가 [calendarWarning] 이 있으면 SnackBar 등으로 안내.
class AddTodoResult {
  const AddTodoResult({required this.todo, this.calendarWarning});

  final Todo todo;
  final String? calendarWarning;
}

final addTodoControllerProvider = Provider<AddTodoController>(
  (ref) => AddTodoController(
    repo: ref.watch(todoRepositoryProvider),
    now: ref.watch(nowProvider),
    calendar: ref.watch(calendarServiceProvider),
  ),
);
