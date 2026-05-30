import '../todo.dart';

/// "미체크 Todo 는 자동으로 다음날 오늘 화면에 이월" 정책.
///
/// DB 의 [Todo.dueAt] 자체는 건드리지 않는다 — 사용자 의도 (원래 일정) 보존을 위해
/// 단지 "오늘 화면에 보여줄지" UI 표시 로직만 결정한다. (실수로 자정에 일정이 바뀌어
/// 보이는 것 방지 + 캘린더 이벤트 시간과의 불일치 방지)
///
/// v1.1: 메모 (`type == TodoType.note`) 는 carryover 대상이 아니다 — note 는 체크
/// 개념이 없어 "어제 미체크 → 오늘로 이월" 자체가 성립 X. 부모-자식 관계도 정책 평가에
/// 영향 없음 (각 todo 는 독립 평가).
class CarryoverPolicy {
  const CarryoverPolicy._();

  /// [todo] 가 [now] 기준 오늘 화면으로 이월되어야 하는가?
  ///
  /// 조건 (모두 만족 시 true):
  /// - task 타입 — note 는 항상 false
  /// - 미체크 (`!todo.isDone`) — 체크된 todo 는 [VisibilityPolicy] 가 별도 처리
  /// - 날짜 지정됨 (`dueAt != null`) — v1.5: 무날짜 항목은 이월 대상이 아니다
  ///   (오늘 화면에 애초에 뜨지 않으므로 이월 개념도 성립 X. 전체보기에서 관리)
  /// - `dueAt` 가 [now] 의 로컬 자정 이전
  ///
  /// 비교는 [now] 의 로컬 timezone 기준 자정 (`DateTime(y, m, d, 0, 0, 0)`).
  /// Todo 의 UTC 시간은 [DateTime.toLocal] 로 변환 후 비교.
  static bool shouldCarryOverToday(Todo todo, DateTime now) {
    if (todo.type == TodoType.note) return false;
    if (todo.isDone) return false;
    if (todo.dueAt == null) return false;
    final due = todo.dueAt!.toLocal();
    final today0 = DateTime(now.year, now.month, now.day);
    return due.isBefore(today0);
  }
}
