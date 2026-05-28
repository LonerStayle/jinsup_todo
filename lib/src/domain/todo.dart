import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'category.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// Todo 의 종류.
///
/// - [task] — 체크 가능한 할 일. 진척률(부모의 [N/M]) 카운트에 포함.
/// - [note] — 단순 메모. 체크박스 없음, doneAt 무관, 진척률 분모 제외.
///   메모장 sub-bullet 중 "→ KV 캐싱 ..." 같은 설명용 항목을 표현.
enum TodoType {
  @JsonValue('task')
  task,
  @JsonValue('note')
  note,
}

/// 할 일 한 건.
///
/// - [doneAt] 가 null 이면 미체크, 값이 있으면 체크된 시각. ([type] = note 면 항상 null.)
/// - [dueAt] 는 사용자가 지정한 일정 (Google Calendar 등록 대상).
/// - [calendarEventId] 가 있으면 캘린더에 이벤트가 등록된 상태.
/// - [createdAt] / [updatedAt] 은 Supabase last-write-wins 충돌 해소에 사용.
/// - [parentId] 가 null 이면 카테고리 직속 root, set 이면 그 todo 의 자식 (트리 노드).
/// - [type] — task / note (기본 task).
/// - [sortOrder] — 같은 parent 내 사용자 정의 순서 (작은 값 먼저). 기본 0, drag-reorder
///   는 v1.2 후속. v1.1 첫 cut 에서는 createdAt fallback 정렬로 충분.
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
    String? parentId,
    @Default(TodoType.task) TodoType type,
    @Default(0) int sortOrder,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

  /// 새 Todo 생성 헬퍼. test 환경에서 결정성을 위해 [now] / [idGen] 주입 가능.
  factory Todo.create({
    required String title,
    required Category category,
    DateTime? dueAt,
    DateTime Function()? now,
    String Function()? idGen,
    String? parentId,
    TodoType type = TodoType.task,
    int sortOrder = 0,
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
      parentId: parentId,
      type: type,
      sortOrder: sortOrder,
    );
  }

  /// 체크된 상태인지. note 는 항상 false (체크 개념 X).
  bool get isDone => type == TodoType.task && doneAt != null;

  /// 체크 토글 — done 이면 미체크로, 미체크면 [at] (기본 now) 체크.
  /// note 타입은 toggle 무시 (체크 개념 없음) — 호출자가 사전 분기하지 못한 케이스를 안전 처리.
  Todo toggleDone({DateTime Function()? now}) {
    if (type == TodoType.note) return this;
    final n = (now ?? DateTime.now)();
    return copyWith(doneAt: isDone ? null : n, updatedAt: n);
  }

  /// 캘린더 이벤트 id 갱신.
  Todo withCalendarEvent(String? eventId, {DateTime Function()? now}) {
    final n = (now ?? DateTime.now)();
    return copyWith(calendarEventId: eventId, updatedAt: n);
  }
}
