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
