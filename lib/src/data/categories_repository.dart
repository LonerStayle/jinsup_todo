import '../domain/category.dart';

/// 카테고리 저장소의 외부 노출 인터페이스.
///
/// LocalCategoriesRepository (Drift only) 또는 SyncingCategoriesRepository
/// (local + outbox + Supabase remote) 가 구현. UI / Controller 는 이 인터페이스만
/// 본다 — 환경 (auth 여부) 에 따라 provider 가 적절한 구현을 주입.
abstract interface class CategoriesRepository {
  Future<Category?> getById(String id);
  Future<List<Category>> getAll();
  Stream<List<Category>> watchAll();
  Future<void> upsert(Category category);
  Future<int> deleteById(String id);
  Future<int> countTodosOfCategory(String id);
}
