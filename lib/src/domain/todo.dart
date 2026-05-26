import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'category.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// 할 일 한 건.
///
/// - [doneAt] 가 null 이면 미체크, 값이 있으면 체크된 시각.
/// - [dueAt] 는 사용자가 지정한 일정 (Google Calendar 등록 대상).
/// - [calendarEventId] 가 있으면 캘린더에 이벤트가 등록된 상태.
/// - [createdAt] / [updatedAt] 은 Supabase last-write-wins 충돌 해소에 사용.
@freezed
abstract class Todo with _$Todo {
  const Todo._();

  const factory Todo({
    required String id,
    required String title,
    required Category category,
    DateTime? dueAt,
    DateTime? doneAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? calendarEventId,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

  /// 새 Todo 생성 헬퍼. test 환경에서 결정성을 위해 [now] / [idGen] 주입 가능.
  factory Todo.create({
    required String title,
    required Category category,
    DateTime? dueAt,
    DateTime Function()? now,
    String Function()? idGen,
  }) {
    final n = (now ?? DateTime.now)();
    return Todo(
      id: (idGen ?? const Uuid().v4)(),
      title: title,
      category: category,
      dueAt: dueAt,
      doneAt: null,
      createdAt: n,
      updatedAt: n,
      calendarEventId: null,
    );
  }

  /// 체크된 상태인지.
  bool get isDone => doneAt != null;

  /// 체크 토글 — done 이면 미체크로, 미체크면 [at] (기본 now) 체크.
  Todo toggleDone({DateTime Function()? now}) {
    final n = (now ?? DateTime.now)();
    return copyWith(doneAt: isDone ? null : n, updatedAt: n);
  }

  /// 캘린더 이벤트 id 갱신.
  Todo withCalendarEvent(String? eventId, {DateTime Function()? now}) {
    final n = (now ?? DateTime.now)();
    return copyWith(calendarEventId: eventId, updatedAt: n);
  }
}
