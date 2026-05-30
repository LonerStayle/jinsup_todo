import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/categories_repository.dart';
import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/policies/category_delete_policy.dart';

/// 카테고리 한 건에 대한 도메인 액션 (add / delete).
///
/// v1.2 — Categories 는 DB row 로 저장되어 사용자가 추가 / 삭제 가능. builtin 도
/// 삭제 가능하지만 카테고리에 속한 todos 가 ≥1 이면 [CategoryDeletePolicy] 가
/// 차단한다 — UI 는 [DeleteCheck.blockedByTodos] 결과로 차단 dialog 를 띄운다.
///
/// Repository abstraction (LocalCategoriesRepository / SyncingCategoriesRepository)
/// 위에 동작 — production 에선 outbox + Supabase push 까지 자동.
class CategoriesController {
  CategoriesController(this._repo);

  final CategoriesRepository _repo;

  /// 새 카테고리 추가 (또는 기존 id 면 update — label / color / icon / sortOrder 갱신).
  Future<void> add(Category category) => _repo.upsert(category);

  /// 카테고리를 그룹으로 이동 (또는 [groupId] == null 이면 미분류로). 사이드바의
  /// '그룹 이동' 메뉴가 호출. 대상 카테고리가 없으면 no-op.
  Future<void> moveToGroup(String categoryId, String? groupId) async {
    final category = await _repo.getById(categoryId);
    if (category == null) return;
    await _repo.upsert(category.copyWith(groupId: groupId));
  }

  /// 작업 2 (K) — 같은 그룹(또는 미분류) 안에서 카테고리 순서를 드래그로 변경.
  ///
  /// [siblings] 는 현재 화면 표시 순서(작은 sortOrder = 위)의 같은 그룹 카테고리들.
  /// ReorderableList 의 ([oldIndex], [newIndex]) 시맨틱을 받아 그 집합에 **연속
  /// 오름차순** sortOrder 를 재부여하고, 값이 바뀐 카테고리만 [repo.upsert]
  /// (동기화 포함). 그룹 소속(groupId)은 바꾸지 않는다 — 순서만.
  ///
  /// 기준값은 집합의 기존 min sortOrder (없으면 0) — 그룹의 화면 위치가 유지된다.
  Future<void> reorderInGroup(
    List<Category> siblings,
    int oldIndex,
    int newIndex,
  ) async {
    if (siblings.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= siblings.length) return;
    // ReorderableList 의 newIndex 는 제거 전 인덱스 기준 → oldIndex 보다 크면 -1 보정.
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target >= siblings.length) target = siblings.length - 1;
    if (target == oldIndex) return; // 변화 없음.

    final reordered = List<Category>.of(siblings);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);

    // base = 기존 집합의 최소 sortOrder (그룹 화면 위치 유지). 비어있을 수 없음.
    var base = siblings.first.sortOrder;
    for (final s in siblings) {
      if (s.sortOrder < base) base = s.sortOrder;
    }
    for (var i = 0; i < reordered.length; i++) {
      final desired = base + i;
      final c = reordered[i];
      if (c.sortOrder != desired) {
        await _repo.upsert(c.copyWith(sortOrder: desired));
      }
    }
  }

  /// id 기준 삭제 시도.
  ///
  /// 반환값:
  /// - [DeleteCheck.ok] — 정책 통과 + delete 완료 (또는 이미 없어서 idempotent).
  /// - [DeleteCheck.blockedByTodos] — 안 todos 가 N건 있어 차단됨. 호출자는
  ///   안내 dialog 를 띄우고 todos 처리를 요청한다.
  Future<DeleteCheck> delete(String id) async {
    final category = await _repo.getById(id);
    if (category == null) {
      // 이미 없으면 ok 반환 (idempotent — 같은 명령 두 번 실행해도 안전).
      return const DeleteCheck.ok();
    }
    final count = await _repo.countTodosOfCategory(id);
    final check = CategoryDeletePolicy.canDelete(category, count);
    if (check.isOk) {
      await _repo.deleteById(id);
    }
    return check;
  }
}

/// 전체 카테고리 stream — sidebar / outline 이 watch.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).watchAll();
});

final categoriesControllerProvider = Provider<CategoriesController>((ref) {
  return CategoriesController(ref.watch(categoriesRepositoryProvider));
});
