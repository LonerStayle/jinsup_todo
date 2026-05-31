import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/groups_repository.dart';
import '../../data/providers.dart';
import '../../domain/group.dart';

/// 그룹 한 건에 대한 도메인 액션 (add / delete). [CategoriesController] 미러.
///
/// v1.3 — 그룹은 카테고리 상위 '큰분류'. 전부 사용자 정의 (builtin 없음).
/// 삭제 정책 (MVP): **차단하지 않는다.** 그룹에 속한 카테고리가 있어도 삭제 가능 —
/// repository 가 그 카테고리들의 groupId 를 null 로 (미분류로 이동) 처리한 뒤
/// 그룹만 지운다. 따라서 todo 데이터는 절대 유실되지 않는다.
///
/// Repository abstraction (LocalGroupsRepository / SyncingGroupsRepository)
/// 위에 동작 — production 에선 outbox + Supabase push 까지 자동.
class GroupsController {
  GroupsController(this._repo);

  final GroupsRepository _repo;

  /// 새 그룹 추가 (또는 기존 id 면 update — label / color / sortOrder 갱신).
  Future<void> add(Group group) => _repo.upsert(group);

  /// id 기준 삭제. 속한 카테고리는 미분류로 이동 (차단 없음). 반환값 = 영향받은
  /// 그룹 row 수 (이미 없으면 0 — idempotent).
  Future<int> delete(String id) => _repo.deleteById(id);

  /// 그룹 순서 변경 (drawer 의 드래그 핸들). [ordered] 는 현재 화면에 보이는 순서의
  /// 그룹 리스트. [ReorderableListView] 의 (oldIndex, newIndex) 규약을 받아 재배열한 뒤
  /// **sortOrder 가 실제로 바뀐 그룹만** upsert 한다 (sync outbox 경유).
  /// 카테고리의 [CategoriesController.reorderInGroup] 미러.
  Future<void> reorder(List<Group> ordered, int oldIndex, int newIndex) async {
    final list = [...ordered];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    for (var i = 0; i < list.length; i++) {
      final g = list[i];
      if (g.sortOrder != i) {
        await _repo.upsert(g.copyWith(sortOrder: i));
      }
    }
  }
}

/// 전체 그룹 stream — sidebar 가 watch.
final groupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(groupsRepositoryProvider).watchAll();
});

final groupsControllerProvider = Provider<GroupsController>((ref) {
  return GroupsController(ref.watch(groupsRepositoryProvider));
});
