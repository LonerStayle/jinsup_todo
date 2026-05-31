import '../todo.dart';

/// "오늘 화면" 에 어떤 Todo 가 보여야 하는지를 결정하는 정책.
///
/// CLAUDE.md 비전:
/// - 미체크 항목은 (이월된 것 포함) 오늘 화면에 보여야 한다 — [CarryoverPolicy] 와 일관
/// - 체크된 항목은 **체크한 당일까지만** 오늘 화면에 보여주고,
///   자정이 지나면 자동으로 사라진다 (히스토리에는 보관).
///
/// v1.1 (트리/메모):
/// - **메모 (`type == TodoType.note`) 는 today 화면에서 제외**. note 는 행동 가능한
///   할 일이 아니라 맥락 정보(예: "→ KV 캐싱 ...") 라 outline / 카테고리 탭 에서만 보인다.
/// - 부모-자식 관계는 정책 평가에 영향 없음. 각 todo 는 자기 자신만 평가 (모델 단순화).
///   자식이 미체크여도 부모가 미체크면 부모는 그대로 visible — 두 항목 독립.
///
/// v1.5 (날짜 기반 '오늘'):
/// - **날짜(`dueAt`)가 지정된 항목만 오늘 화면에 노출**한다. 날짜 없는 항목(dueAt==null)은
///   '오늘' 이 아니라 '전체보기'(카테고리별)에서 관리한다 — 과거엔 `dueAt ?? createdAt`
///   폴백으로 무날짜 항목이 전부 오늘에 떠서 영구 이월되던 문제를 제거.
/// - 미래(내일 이후) 날짜는 오늘에 뜨지 않는다. 오늘 = 오늘 날짜 + 지난 미체크(이월)뿐.
class VisibilityPolicy {
  const VisibilityPolicy._();

  /// [todo] 가 [now] 기준 오늘 화면에 보여야 하는가?
  ///
  /// note: type=note 면 항상 false (today 화면 노출 X).
  /// 날짜 미지정(`dueAt == null`): 항상 false — 오늘 화면 대상 아님(전체보기에서 관리).
  ///
  /// 미체크: `dueAt` 의 local 날짜가 내일 자정 이전(= 오늘 또는 그 이전 = 이월) 이면 visible.
  ///   미래(내일 이후) 날짜는 보이지 않는다.
  ///
  /// 체크됨: `doneAt.toLocal()` 의 날짜가 오늘 자정 이상.
  ///   → 체크한 그 날까지만 visible. 다음날 자정에 자동 hide.
  ///
  /// (`isDone == true` 인데 `doneAt == null` 인 경우는 [Todo] 의 invariant 상
  /// 발생하지 않는다.)
  static bool isVisibleToday(Todo todo, DateTime now) {
    if (todo.type == TodoType.note) return false;
    // date-repeat: 반복 마스터는 규칙 보유 숨김 템플릿 — 모든 목록에서 제외.
    // 실제 노출은 발생일마다 생성되는 인스턴스가 담당한다.
    if (todo.isSeriesMaster) return false;
    if (todo.dueAt == null) return false;

    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = today0.add(const Duration(days: 1));

    if (todo.isDone) {
      final done = todo.doneAt!.toLocal();
      // done 이 오늘 0시 이상 (= 오늘 또는 미래) 이면 visible.
      return !done.isBefore(today0);
    }

    final due = todo.dueAt!.toLocal();
    // due 가 내일 자정 이전 (= 오늘 또는 그 이전) 이면 visible. 미래는 제외.
    return due.isBefore(tomorrow0);
  }
}
