import '../../domain/category.dart';
import '../categories_repository.dart';
import 'categories_dao.dart';

/// 로컬 전용 [CategoriesRepository] — CategoriesDao 직접 위임.
///
/// 미인증 / Supabase 미설정 환경 (.env 누락 등) 에서 사용. CRUD 이후 remote push
/// 없이 즉시 완료.
class LocalCategoriesRepository implements CategoriesRepository {
  LocalCategoriesRepository(this._dao);

  final CategoriesDao _dao;

  @override
  Future<Category?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Category>> getAll() => _dao.getAll();

  @override
  Stream<List<Category>> watchAll() => _dao.watchAll();

  @override
  Future<void> upsert(Category category) => _dao.upsert(category);

  @override
  Future<int> deleteById(String id) => _dao.deleteById(id);

  @override
  Future<int> countTodosOfCategory(String id) => _dao.countTodosOfCategory(id);
}
