import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/group.dart';

/// GroupsDao 검증 — CRUD + 정렬 + 카테고리 detach.
///
/// 매 테스트는 in-memory AppDatabase 로 fresh start. groups 는 seed 없음 (빈 상태).
/// categories 는 onCreate 가 5 builtin 을 seed 하므로 baseline 존재.
void main() {
  group('GroupsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('초기 상태는 그룹 0개 (seed 없음)', () async {
      final list = await db.groupsDao.watchAll().first;
      expect(list, isEmpty);
    });

    test('upsert — 새 그룹 + watchAll 에 sortOrder asc 로 반영', () async {
      await db.groupsDao.upsert(
        const Group(
          id: 'grp-b',
          label: '사이드',
          colorValue: 0xFF22C55E,
          sortOrder: 10,
        ),
      );
      await db.groupsDao.upsert(
        const Group(
          id: 'grp-a',
          label: '회사',
          colorValue: 0xFF2A66FF,
          sortOrder: 5,
        ),
      );
      final list = await db.groupsDao.watchAll().first;
      expect(list.map((g) => g.id).toList(), ['grp-a', 'grp-b']);
    });

    test('upsert — 같은 id 면 update (label 갱신)', () async {
      await db.groupsDao.upsert(
        const Group(id: 'grp-a', label: '회사', colorValue: 0xFF2A66FF),
      );
      await db.groupsDao.upsert(
        const Group(id: 'grp-a', label: '회사 (변경)', colorValue: 0xFF2A66FF),
      );
      final got = await db.groupsDao.getById('grp-a');
      expect(got, isNotNull);
      expect(got!.label, '회사 (변경)');
    });

    test('deleteById — 그룹 hard delete', () async {
      await db.groupsDao.upsert(
        const Group(id: 'grp-a', label: '회사', colorValue: 0xFF2A66FF),
      );
      final affected = await db.groupsDao.deleteById('grp-a');
      expect(affected, 1);
      expect(await db.groupsDao.getById('grp-a'), isNull);
    });

    test('categoriesInGroup — 매칭 카테고리를 groupId=null 로 미리 비워 반환', () async {
      await db.groupsDao.upsert(
        const Group(id: 'grp-a', label: '회사', colorValue: 0xFF2A66FF),
      );
      // 카테고리 2개를 grp-a 에 배정.
      await db.categoriesDao.upsert(Category.work.copyWith(groupId: 'grp-a'));
      await db.categoriesDao.upsert(Category.daily.copyWith(groupId: 'grp-a'));

      final inGroup = await db.groupsDao.categoriesInGroup('grp-a');
      expect(inGroup.map((c) => c.id).toSet(), {'work', 'daily'});
      // 반환되는 도메인은 이동 후 값(null) 으로 미리 비워져 있다.
      for (final c in inGroup) {
        expect(c.groupId, isNull);
      }
    });

    test('detachCategories — 속한 카테고리들의 groupId 를 null 로 (미분류 이동)', () async {
      await db.groupsDao.upsert(
        const Group(id: 'grp-a', label: '회사', colorValue: 0xFF2A66FF),
      );
      await db.categoriesDao.upsert(Category.work.copyWith(groupId: 'grp-a'));
      await db.categoriesDao.upsert(Category.daily.copyWith(groupId: 'grp-a'));
      // 다른 그룹 카테고리는 영향 없어야 함.
      await db.categoriesDao.upsert(Category.idea.copyWith(groupId: 'grp-z'));

      final affected = await db.groupsDao.detachCategories('grp-a');
      expect(affected, 2);

      expect((await db.categoriesDao.getById('work'))!.groupId, isNull);
      expect((await db.categoriesDao.getById('daily'))!.groupId, isNull);
      // grp-z 카테고리는 그대로.
      expect((await db.categoriesDao.getById('idea'))!.groupId, 'grp-z');
    });
  });
}
