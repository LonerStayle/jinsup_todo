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
/// - [endAt] / [isAllDay] / [timeAnchor] — fast-tasks 날짜·기간 모델 (아래 참조).
enum TodoDateMode {
  /// dueAt 없음.
  none,

  /// 단일·하루종일 — dueAt(date@00:00), isAllDay=true, endAt=null.
  allDay,

  /// 단일·시작시간만 — dueAt(date+time), isAllDay=false, endAt=null, timeAnchor='start'.
  startTime,

  /// 단일·마감시간만 — dueAt(date+time), isAllDay=false, endAt=null, timeAnchor='end'.
  endTime,

  /// 기간 — dueAt(시작) + endAt(종료). isAllDay 로 양끝 시간 표시 여부 단순화.
  range,
}

@freezed
abstract class Todo with _$Todo {
  const Todo._();

  const factory Todo({
    required String id,
    required String title,
    @JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson)
    required Category category,
    DateTime? dueAt,
    DateTime? doneAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? calendarEventId,
    String? parentId,
    @Default(TodoType.task) TodoType type,
    @Default(0) int sortOrder,
    // v1.2 — 상세 메모 (long text). nullable + 누락 시 null 로 안전 fallback.
    String? description,
    // ── 날짜·기간 모델 (fast-tasks 4/5/1) — dueAt 은 앵커로 그대로 유지 ──────────
    // [endAt] — 기간 모드의 종료 시각. 단일 모드면 null.
    DateTime? endAt,
    // [isAllDay] — true 면 시간 미표시 (화면 어디에도 00:00 을 찍지 않음).
    @Default(false) bool isAllDay,
    // [timeAnchor] — 단일·시간 모드에서 dueAt 이 '시작'('start')인지 '마감'('end')인지.
    // 하루종일·기간 모드에서는 의미 없음 (기본 'start' 유지).
    @Default('start') String timeAnchor,
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
    String? description,
    DateTime? endAt,
    bool isAllDay = false,
    String timeAnchor = 'start',
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
      description: description,
      endAt: endAt,
      isAllDay: isAllDay,
      timeAnchor: timeAnchor,
    );
  }

  /// 직렬화된 필드 조합으로부터 현재 날짜 모드를 도출. UI / 캘린더 매핑의 단일 출처.
  TodoDateMode get dateMode {
    if (dueAt == null) return TodoDateMode.none;
    if (endAt != null) return TodoDateMode.range;
    if (isAllDay) return TodoDateMode.allDay;
    return timeAnchor == 'end' ? TodoDateMode.endTime : TodoDateMode.startTime;
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

/// Todo JSON 의 `category` 필드를 nested object 가 아닌 string id 로 직렬화 유지.
/// v1.0 / v1.1 의 옛 payload (예: `"category": "work"`) 가 그대로 복원된다.
///
/// ⚠️ v1.2 사용자 추가 카테고리 id ('cat-...') 는 builtin 이 아니라 [Category.tryFromId]
/// 가 null 을 준다. 이때 [Category.daily] 로 붕괴시키면 안 된다 — outbox flush 가
/// toJson→fromJson 으로 복원해 Supabase 에 업로드하므로, 붕괴 시 원격 row 의 category 가
/// 전부 'daily' 로 오염되고 다른 기기(모바일)에서 모든 항목이 '일상'으로 보인다.
/// 미지 id 는 id 만 보존하는 placeholder 로 복원한다 (label/color 는 categories join 으로
/// 복원되므로 메타는 쓰이지 않음 — [SupabaseTodosApi._fromRow] / [TodosDao] 와 동일 규칙).
Category _categoryFromJson(Object? value) {
  if (value is String) {
    return Category.tryFromId(value) ?? _placeholderCategory(value);
  }
  if (value is Map<String, dynamic>) {
    return Category.fromJson(value);
  }
  return Category.daily;
}

/// 미지 카테고리 id 를 id 만 보존한 채 안전 복원. (SupabaseTodosApi._fromRow 와 동일.)
Category _placeholderCategory(String id) => Category(
  id: id,
  label: '기타',
  iconCodePoint: 0xe893,
  colorValue: 0xFF9E9E9E,
);

String _categoryToJson(Category category) => category.id;
