import '../domain/group.dart';

/// 그룹 저장소의 외부 노출 인터페이스. [CategoriesRepository] 미러.
///
/// LocalGroupsRepository (Drift only) 또는 SyncingGroupsRepository
/// (local + outbox + Supabase remote) 가 구현. UI / Controller 는 이 인터페이스만
/// 본다 — 환경 (auth 여부) 에 따라 provider 가 적절한 구현을 주입.
abstract interface class GroupsRepository {
  Future<Group?> getById(String id);
  Future<List<Group>> getAll();
  Stream<List<Group>> watchAll();
  Future<void> upsert(Group group);

  /// 그룹 삭제. 삭제 전 그 그룹에 속한 카테고리들의 groupId 를 null 로 (미분류로
  /// 이동) 처리한 뒤 그룹 row 를 지운다. 차단하지 않는다.
  Future<int> deleteById(String id);
}
