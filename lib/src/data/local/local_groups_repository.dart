import '../../domain/group.dart';
import '../groups_repository.dart';
import 'groups_dao.dart';

/// 로컬 전용 [GroupsRepository] — GroupsDao 직접 위임. [LocalCategoriesRepository] 미러.
///
/// 미인증 / Supabase 미설정 환경에서 사용. CRUD 이후 remote push 없이 즉시 완료.
/// 삭제 시 detachCategories (속한 카테고리 미분류로 이동) 후 그룹 row 삭제.
class LocalGroupsRepository implements GroupsRepository {
  LocalGroupsRepository(this._dao);

  final GroupsDao _dao;

  @override
  Future<Group?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Group>> getAll() => _dao.getAll();

  @override
  Stream<List<Group>> watchAll() => _dao.watchAll();

  @override
  Future<void> upsert(Group group) => _dao.upsert(group);

  @override
  Future<int> deleteById(String id) async {
    await _dao.detachCategories(id);
    return _dao.deleteById(id);
  }
}
