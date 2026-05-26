import '../todo.dart';

/// "오늘 화면" 에 어떤 Todo 가 보여야 하는지를 결정하는 정책.
///
/// CLAUDE.md 비전:
/// - 미체크 항목은 (이월된 것 포함) 오늘 화면에 보여야 한다 — [CarryoverPolicy] 와 일관
/// - 체크된 항목은 **체크한 당일까지만** 오늘 화면에 보여주고,
///   자정이 지나면 자동으로 사라진다 (히스토리에는 보관).
class VisibilityPolicy {
  const VisibilityPolicy._();

  /// [todo] 가 [now] 기준 오늘 화면에 보여야 하는가?
  ///
  /// 미체크: effective date (`dueAt ?? createdAt`) 의 local 시각이 내일 자정 이전.
  ///   → 오늘 또는 그 이전 (= 이월) 의 미체크 todo 는 모두 visible.
  ///
  /// 체크됨: `doneAt.toLocal()` 의 날짜가 오늘 자정 이상.
  ///   → 체크한 그 날까지만 visible. 다음날 자정에 자동 hide.
  ///
  /// (`isDone == true` 인데 `doneAt == null` 인 경우는 [Todo] 의 invariant 상
  /// 발생하지 않는다.)
  static bool isVisibleToday(Todo todo, DateTime now) {
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = today0.add(const Duration(days: 1));

    if (todo.isDone) {
      final done = todo.doneAt!.toLocal();
      // done 이 오늘 0시 이상 (= 오늘 또는 미래) 이면 visible.
      return !done.isBefore(today0);
    }

    final effective = (todo.dueAt ?? todo.createdAt).toLocal();
    // effective 가 내일 자정 이전 (= 오늘 또는 그 이전) 이면 visible.
    return effective.isBefore(tomorrow0);
  }
}
