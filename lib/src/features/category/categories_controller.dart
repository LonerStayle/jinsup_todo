import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/categories_dao.dart';
import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/policies/category_delete_policy.dart';

/// 카테고리 한 건에 대한 도메인 액션 (add / delete).
///
/// v1.2 — Categories 는 DB row 로 저장되어 사용자가 추가 / 삭제 가능. builtin 도
/// 삭제 가능하지만 카테고리에 속한 todos 가 ≥1 이면 [CategoryDeletePolicy] 가
/// 차단한다 — UI 는 [DeleteCheck.blockedByTodos] 결과로 차단 dialog 를 띄운다.
class CategoriesController {
  CategoriesController(this._dao);

  final CategoriesDao _dao;

  /// 새 카테고리 추가 (또는 기존 id 면 update — label / color / icon / sortOrder 갱신).
  Future<void> add(Category category) => _dao.upsert(category);

  /// id 기준 삭제 시도.
  ///
  /// 반환값:
  /// - [DeleteCheck.ok] — 정책 통과 + delete 완료 (또는 이미 없어서 idempotent).
  /// - [DeleteCheck.blockedByTodos] — 안 todos 가 N건 있어 차단됨. 호출자는
  ///   안내 dialog 를 띄우고 todos 처리를 요청한다.
  Future<DeleteCheck> delete(String id) async {
    final category = await _dao.getById(id);
    if (category == null) {
      // 이미 없으면 ok 반환 (idempotent — 같은 명령 두 번 실행해도 안전).
      return const DeleteCheck.ok();
    }
    final count = await _dao.countTodosOfCategory(id);
    final check = CategoryDeletePolicy.canDelete(category, count);
    if (check.isOk) {
      await _dao.deleteById(id);
    }
    return check;
  }
}

/// 전체 카테고리 stream — sidebar / outline 이 watch.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.categoriesDao.watchAll();
});

final categoriesControllerProvider = Provider<CategoriesController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoriesController(db.categoriesDao);
});
