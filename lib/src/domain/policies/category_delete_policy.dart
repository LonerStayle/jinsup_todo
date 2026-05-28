import '../category.dart';

/// 카테고리 삭제 차단 정책.
///
/// v1.2 비전:
/// - builtin / 사용자 정의 구분 없이 hard delete 가능.
/// - 단, 카테고리에 속한 todos 가 0건이어야 한다. ≥1 이면 차단하고 다이얼로그로
///   "먼저 다른 카테고리로 옮기거나 todos 부터 삭제하세요" 안내 (UI 측 책임).
///
/// 정책은 pure 함수로 노출 — UI / Controller 가 동일한 출처에서 가져다 쓴다.
class CategoryDeletePolicy {
  const CategoryDeletePolicy._();

  /// 삭제 가능 여부.
  ///
  /// [todoCount] 는 [category] 에 속한 todos 의 개수 (호출자가 DAO 로 미리 계산).
  /// 0 이면 [DeleteCheck.ok], 그렇지 않으면 [DeleteCheck.blockedByTodos].
  static DeleteCheck canDelete(Category category, int todoCount) {
    if (todoCount > 0) {
      return DeleteCheck.blockedByTodos(todoCount);
    }
    return const DeleteCheck.ok();
  }
}

/// [CategoryDeletePolicy.canDelete] 의 결과.
sealed class DeleteCheck {
  const DeleteCheck();

  const factory DeleteCheck.ok() = _DeleteOk;

  const factory DeleteCheck.blockedByTodos(int count) = _DeleteBlockedByTodos;

  /// 패턴 매칭 헬퍼 — `if (result.isOk) ...` 형태.
  bool get isOk => this is _DeleteOk;
}

final class _DeleteOk extends DeleteCheck {
  const _DeleteOk();

  @override
  bool operator ==(Object other) => other is _DeleteOk;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'DeleteCheck.ok';
}

final class _DeleteBlockedByTodos extends DeleteCheck {
  const _DeleteBlockedByTodos(this.count);

  /// 안 todos 의 개수.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is _DeleteBlockedByTodos && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'DeleteCheck.blockedByTodos($count)';
}
