import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';
import 'package:solo_todo/src/features/outline/outline_screen.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

void main() {
  Todo make({
    required String id,
    String title = 't',
    Category category = Category.work,
    String? parentId,
    TodoType type = TodoType.task,
    DateTime? doneAt,
  }) => Todo(
    id: id,
    title: title,
    category: category,
    dueAt: null,
    doneAt: doneAt,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
    parentId: parentId,
    type: type,
  );

  /// OutlineScreen 을 in-memory override 로 mount.
  ///
  /// [rootsByCategory] : 각 카테고리의 root todos.
  /// [childrenByParent] : 각 parentId → 자식 list.
  /// [allTodos] : computeSubtreeProgress 가 walking 할 평탄 list.
  Future<void> mount(
    WidgetTester tester, {
    required Map<Category, List<Todo>> rootsByCategory,
    Map<String, List<Todo>> childrenByParent = const {},
    required List<Todo> allTodos,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allTodosProvider.overrideWith((_) => Stream.value(allTodos)),
          rootsOfCategoryProvider.overrideWith(
            (_, cat) => Stream.value(rootsByCategory[cat] ?? const <Todo>[]),
          ),
          childrenOfProvider.overrideWith(
            (_, parentId) =>
                Stream.value(childrenByParent[parentId] ?? const <Todo>[]),
          ),
          // v1.2 — OutlineScreen 이 categoriesProvider 를 watch (동적 카테고리).
          categoriesProvider.overrideWith(
            (_) => Stream.value(Category.builtinSeeds),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: const Scaffold(body: OutlineScreen()),
        ),
      ),
    );
    // stream emit 흐름 확보 — 손자까지 watch 가 도착하려면 depth 만큼 frame 필요.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('빈 트리 — 5 카테고리 헤더만 표시, progress 없음', (tester) async {
    await mount(tester, rootsByCategory: const {}, allTodos: const []);

    expect(find.text('전체보기'), findsOneWidget);
    // 5 카테고리 헤더 모두 노출.
    for (final c in Category.values) {
      expect(find.text(c.label), findsOneWidget);
    }
    // ProgressBadge 의 "N/M" 숫자 라벨 패턴은 안 보여야 (total 0 → 카드 자체 hide).
    // RegExp(r'^\d+/\d+$') 로 "전체보기 / 폴더 / 메모" 같은 헤더 텍스트와 분리.
    expect(find.textContaining(RegExp(r'^\d+/\d+$')), findsNothing);
  });

  testWidgets('카테고리에 task root 2건 (1 done) → 헤더에 1/2 + root 표시', (
    tester,
  ) async {
    final root1 = make(id: 'r1', title: '캔버스 첨부 오류');
    final root2Done = make(
      id: 'r2',
      title: '오타 수정',
      doneAt: DateTime(2026, 5, 27, 10),
    );
    await mount(
      tester,
      rootsByCategory: {
        Category.work: [root1, root2Done],
      },
      allTodos: [root1, root2Done],
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('캔버스 첨부 오류'), findsOneWidget);
    expect(find.text('오타 수정'), findsOneWidget);
  });

  testWidgets('펼침 → 접힘 토글 — 카테고리 row tap 시 자식 root 들 사라짐', (tester) async {
    final root = make(id: 'r', title: '회사 root');
    await mount(
      tester,
      rootsByCategory: {
        Category.work: [root],
      },
      allTodos: [root],
    );

    expect(find.text('회사 root'), findsOneWidget);

    // 카테고리 헤더 tap → 접힘.
    await tester.tap(find.byKey(const ValueKey('outline-category-work')));
    await tester.pump();
    expect(find.text('회사 root'), findsNothing);

    // 한 번 더 tap → 다시 펼침.
    await tester.tap(find.byKey(const ValueKey('outline-category-work')));
    await tester.pump();
    expect(find.text('회사 root'), findsOneWidget);
  });

  testWidgets('자식 트리 — folder 노드 펼침 / 자식 표시 / [done/total] 누적', (tester) async {
    // 회사 > 넥서스 (root) > [캔버스(미완), narrative(done)].
    final nexus = make(id: 'nexus', title: '넥서스');
    final child1 = make(id: 'c1', title: '캔버스 첨부 오류', parentId: 'nexus');
    final child2Done = make(
      id: 'c2',
      title: 'narrative 에러',
      parentId: 'nexus',
      doneAt: DateTime(2026, 5, 27, 10),
    );

    await mount(
      tester,
      rootsByCategory: {
        Category.work: [nexus],
      },
      childrenByParent: {
        'nexus': [child1, child2Done],
      },
      allTodos: [nexus, child1, child2Done],
    );

    // nexus 폴더는 default 펼침 — 자식 두 개 보임.
    expect(find.text('넥서스'), findsOneWidget);
    expect(find.text('캔버스 첨부 오류'), findsOneWidget);
    expect(find.text('narrative 에러'), findsOneWidget);

    // 카테고리 헤더의 [N/M] — nexus(task, 미완) + c1(미완) + c2(done) = 1/3.
    expect(find.text('1/3'), findsAtLeastNWidgets(1), reason: '카테고리 누적 진척률');

    // nexus 노드 자체에도 진척률 ([1/2] — c1 미완 + c2 done).
    expect(find.text('1/2'), findsAtLeastNWidgets(1));

    // 자식 노드 펼침을 접으면 자식들 사라짐.
    await tester.tap(find.byKey(const ValueKey('outline-node-nexus')));
    await tester.pump();
    expect(find.text('캔버스 첨부 오류'), findsNothing);
    expect(find.text('narrative 에러'), findsNothing);
    // 부모 nexus 자체는 여전히 보임.
    expect(find.text('넥서스'), findsOneWidget);
  });

  testWidgets('note 는 분모/분자 모두 제외 (진척률 카운트에 미포함)', (tester) async {
    // 회사 root: task 1 (done) + note 2 (= [1/1], note 두 건은 분모 제외).
    final task = make(
      id: 't',
      title: '체크할 일',
      doneAt: DateTime(2026, 5, 27, 10),
    );
    final note1 = make(id: 'n1', title: '메모1', type: TodoType.note);
    final note2 = make(id: 'n2', title: '메모2', type: TodoType.note);

    await mount(
      tester,
      rootsByCategory: {
        Category.work: [task, note1, note2],
      },
      allTodos: [task, note1, note2],
    );

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('자손 진척률 walk — 손자까지 누적 (depth 들여쓰기 포함)', (tester) async {
    // 회사 > 프로젝트 (root) > 폴더A (folder) > task1(done), task2(미완)
    final project = make(id: 'p', title: 'JS슈퍼');
    final folderA = make(id: 'fa', title: '울트라 모드', parentId: 'p');
    final g1Done = make(
      id: 'g1',
      title: '워크트리',
      parentId: 'fa',
      doneAt: DateTime(2026, 5, 27, 10),
    );
    final g2 = make(id: 'g2', title: 'brainstorm', parentId: 'fa');

    await mount(
      tester,
      rootsByCategory: {
        Category.work: [project],
      },
      childrenByParent: {
        'p': [folderA],
        'fa': [g1Done, g2],
      },
      allTodos: [project, folderA, g1Done, g2],
    );

    // 카테고리 누적 — p(미완) + fa(미완) + g1(done) + g2(미완) = 1/4.
    expect(find.text('1/4'), findsAtLeastNWidgets(1));
    // p 노드의 subtree 진척률 — fa(미완) + g1(done) + g2(미완) = 1/3.
    expect(find.text('1/3'), findsAtLeastNWidgets(1));
    // 모든 노드 화면에 표시 (default 펼침).
    expect(find.text('JS슈퍼'), findsOneWidget);
    expect(find.text('울트라 모드'), findsOneWidget);
    expect(find.text('워크트리'), findsOneWidget);
    expect(find.text('brainstorm'), findsOneWidget);
  });

  testWidgets('자식 없는 leaf 노드는 chevron 자리 비워두고 정렬 유지', (tester) async {
    final leaf = make(id: 'leaf', title: '단독 task');
    await mount(
      tester,
      rootsByCategory: {
        Category.work: [leaf],
      },
      allTodos: [leaf],
    );

    // leaf 는 chevron 없음 — outline-node-leaf 키가 붙은 InkWell 의 onTap 이 null.
    // (Material InkResponse 등 내부 InkWell 가 여러 개 있을 수 있어 키 기반으로 first 만.)
    final node = tester.widget<InkWell>(
      find.byKey(const ValueKey('outline-node-leaf')),
    );
    expect(node.onTap, isNull, reason: 'leaf 는 펼침 동작 없음');
  });

  testWidgets('task 노드는 체크 토글 버튼 노출 (하위 트리 포함), note 는 없음', (tester) async {
    // 회사 > 부모 task > 자식 task + 자식 note.
    final parent = make(id: 'p', title: '부모 할 일');
    final childTask = make(id: 'c1', title: '자식 할 일', parentId: 'p');
    final childNote = make(
      id: 'c2',
      title: '자식 메모',
      parentId: 'p',
      type: TodoType.note,
    );
    await mount(
      tester,
      rootsByCategory: {
        Category.work: [parent],
      },
      childrenByParent: {
        'p': [childTask, childNote],
      },
      allTodos: [parent, childTask, childNote],
    );

    // task 는 부모·자식 모두 체크 토글 버튼 존재.
    expect(find.byKey(const ValueKey('outline-check-p')), findsOneWidget);
    expect(find.byKey(const ValueKey('outline-check-c1')), findsOneWidget);
    // 체크 버튼은 tap 가능한 InkWell.
    final parentCheck = tester.widget<InkWell>(
      find.byKey(const ValueKey('outline-check-p')),
    );
    expect(parentCheck.onTap, isNotNull);
    // note 는 체크 버튼 없음 (정적 sticky_note 아이콘).
    expect(find.byKey(const ValueKey('outline-check-c2')), findsNothing);
  });
}
