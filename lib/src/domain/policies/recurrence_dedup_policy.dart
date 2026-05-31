import '../todo.dart';

/// dedup 결과 — '오늘 화면'에 실제 보일 목록 + 시리즈별 숨김 건수.
class DedupedToday {
  /// 화면에 노출할 Todo 목록 (입력 순서 보존).
  /// 같은 반복 시리즈의 미체크가 2건 이상이면 가장 이른 1건(leader)만 포함.
  final List<Todo> visible;

  /// `seriesId` → 숨겨진 추가 미체크 건수 (leader 에 "외 N건" 배지로 표시).
  /// 1건뿐인 시리즈는 키가 없다.
  final Map<String, int> hiddenCountBySeries;

  const DedupedToday({
    required this.visible,
    required this.hiddenCountBySeries,
  });
}

/// "같은 반복의 미체크 누적은 오늘 화면에 1건만" 정책 (FR-4).
///
/// PRD 결정: 반복 인스턴스는 일반 Todo 처럼 이월(FR-3)되지만, 가독성을 위해
/// 같은 `seriesId` 미체크가 쌓이면 **가장 이른 발생분 1건만** 노출하고 나머지는
/// 묶음(배지)으로 표현한다. 데이터는 삭제하지 않는다 — 순수 표시 레이어 변환.
///
/// 적용 대상은 **미체크 task 인스턴스**뿐. 체크된 인스턴스(당일까지 노출)·비반복
/// Todo 는 그대로 통과한다.
class RecurrenceDedupPolicy {
  const RecurrenceDedupPolicy._();

  /// [todays] = VisibilityPolicy 통과 + 정렬된 오늘 목록. 입력 순서를 보존한다.
  static DedupedToday dedupe(List<Todo> todays) {
    // 1) 시리즈별 미체크 인스턴스 수집.
    final undoneBySeries = <String, List<Todo>>{};
    for (final t in todays) {
      final sid = t.seriesId;
      if (sid != null && t.type == TodoType.task && !t.isDone) {
        (undoneBySeries[sid] ??= <Todo>[]).add(t);
      }
    }

    // 2) 2건 이상인 시리즈만 leader 선정(가장 이른 dueAt, 동률은 createdAt).
    final leaderIdBySeries = <String, String>{};
    final hidden = <String, int>{};
    for (final entry in undoneBySeries.entries) {
      if (entry.value.length < 2) continue;
      final sorted = [...entry.value]..sort(_byDueThenCreated);
      leaderIdBySeries[entry.key] = sorted.first.id;
      hidden[entry.key] = sorted.length - 1;
    }

    // 3) 순서 보존하며 leader 아닌 미체크 시리즈 멤버 제거.
    final visible = <Todo>[];
    for (final t in todays) {
      final sid = t.seriesId;
      final collapsed =
          sid != null &&
          t.type == TodoType.task &&
          !t.isDone &&
          (undoneBySeries[sid]?.length ?? 0) >= 2;
      if (collapsed) {
        if (leaderIdBySeries[sid] == t.id) visible.add(t);
        // leader 아니면 숨김.
      } else {
        visible.add(t);
      }
    }

    return DedupedToday(visible: visible, hiddenCountBySeries: hidden);
  }

  static int _byDueThenCreated(Todo a, Todo b) {
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad != null && bd != null) {
      final c = ad.compareTo(bd);
      if (c != 0) return c;
    }
    return a.createdAt.compareTo(b.createdAt);
  }
}
