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
    String? description,
  }) => Todo(
    id: id,
    title: title,
    description: description,
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
  /// [rootsByCategory] : 각 카테고리의 root todos (task + note 섞임 가능).
  /// [childrenByParent] : 각 parentId → 자식 list.
  /// [allTodos] : computeSubtreeProgress walk + 메모 탭 note 필터의 출처.
  ///
  /// 파생 provider (taskRootsOf / childTasksOf / notesOfCategory) 는 base provider
  /// 의 stream override 를 그대로 받아 in-memory 필터링하므로 별도 override 불필요.
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

  /// 메모 탭으로 전환 (default 는 체크리스트 탭). 탭 전환 애니메이션 + stream emit
  /// 완료까지 settle.
  Future<void> openNotesTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, '메모'));
    await tester.pumpAndSettle();
  }

  group('탭 구조', () {
    testWidgets('체크리스트 / 메모 탭 + 빈 트리 — 5 카테고리 헤더만, progress 없음', (
      tester,
    ) async {
      await mount(tester, rootsByCategory: const {}, allTodos: const []);

      expect(find.text('전체보기'), findsOneWidget);
      expect(find.text('체크리스트'), findsOneWidget);
      expect(find.text('메모'), findsOneWidget);
      // 체크리스트 탭(default) — 5 카테고리 헤더 모두 노출.
      for (final c in Category.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.textContaining(RegExp(r'^\d+/\d+$')), findsNothing);
    });
  });

  group('체크리스트 탭 (task 트리)', () {
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

      await tester.tap(find.byKey(const ValueKey('outline-category-work')));
      await tester.pump();
      expect(find.text('회사 root'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('outline-category-work')));
      await tester.pump();
      expect(find.text('회사 root'), findsOneWidget);
    });

    testWidgets('자식 트리 — folder 노드 펼침 / 자식 표시 / [done/total] 누적', (
      tester,
    ) async {
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

      expect(find.text('넥서스'), findsOneWidget);
      expect(find.text('캔버스 첨부 오류'), findsOneWidget);
      expect(find.text('narrative 에러'), findsOneWidget);

      expect(find.text('1/3'), findsAtLeastNWidgets(1), reason: '카테고리 누적 진척률');
      expect(find.text('1/2'), findsAtLeastNWidgets(1));

      await tester.tap(find.byKey(const ValueKey('outline-node-nexus')));
      await tester.pump();
      expect(find.text('캔버스 첨부 오류'), findsNothing);
      expect(find.text('narrative 에러'), findsNothing);
      expect(find.text('넥서스'), findsOneWidget);
    });

    testWidgets('note root 는 체크리스트 탭에서 제외 — task 만 진척률 1/1', (tester) async {
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

      // 체크리스트 탭(default) 에는 note 가 보이지 않고 task 만.
      expect(find.text('체크할 일'), findsOneWidget);
      expect(find.text('메모1'), findsNothing);
      expect(find.text('메모2'), findsNothing);
      expect(find.text('1/1'), findsOneWidget);
    });

    testWidgets('note 자식은 체크리스트 트리에서 제외 (task 자식만 노출)', (tester) async {
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

      expect(find.text('부모 할 일'), findsOneWidget);
      expect(find.text('자식 할 일'), findsOneWidget);
      // note 자식은 체크리스트 탭에서 숨김.
      expect(find.text('자식 메모'), findsNothing);
      // task 는 부모·자식 모두 체크 토글 버튼 존재.
      expect(find.byKey(const ValueKey('outline-check-p')), findsOneWidget);
      expect(find.byKey(const ValueKey('outline-check-c1')), findsOneWidget);
      final parentCheck = tester.widget<InkWell>(
        find.byKey(const ValueKey('outline-check-p')),
      );
      expect(parentCheck.onTap, isNotNull);
    });

    testWidgets('자식 없는 leaf 노드는 chevron 없음 (펼침 동작 X)', (tester) async {
      final leaf = make(id: 'leaf', title: '단독 task');
      await mount(
        tester,
        rootsByCategory: {
          Category.work: [leaf],
        },
        allTodos: [leaf],
      );

      final node = tester.widget<InkWell>(
        find.byKey(const ValueKey('outline-node-leaf')),
      );
      expect(node.onTap, isNull, reason: 'leaf 는 펼침 동작 없음');
    });
  });

  group('메모 탭 (note 평탄 목록)', () {
    testWidgets('메모 탭에는 note 만, task 는 안 보임', (tester) async {
      final task = make(id: 't', title: '체크할 일');
      final note1 = make(
        id: 'n1',
        title: '메모1',
        type: TodoType.note,
        description: '메모 본문',
      );
      final note2 = make(id: 'n2', title: '메모2', type: TodoType.note);

      await mount(
        tester,
        rootsByCategory: {
          Category.work: [task, note1, note2],
        },
        allTodos: [task, note1, note2],
      );

      await openNotesTab(tester);

      // note 카드 노출.
      expect(find.byKey(const ValueKey('outline-note-n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('outline-note-n2')), findsOneWidget);
      expect(find.text('메모1'), findsOneWidget);
      expect(find.text('메모2'), findsOneWidget);
      expect(find.text('메모 본문'), findsOneWidget);
      // task 는 메모 탭에 없음.
      expect(find.text('체크할 일'), findsNothing);
      // 메모는 체크 토글 없음.
      expect(find.byKey(const ValueKey('outline-check-t')), findsNothing);
    });

    testWidgets('note 가 트리 깊이와 무관하게 평탄 나열 (자식 note 포함)', (tester) async {
      // task root > note 자식 — 메모 탭은 트리 무관하게 카테고리의 모든 note 를 나열.
      final root = make(id: 'r', title: '루트 task');
      final childNote = make(
        id: 'cn',
        title: '깊은 메모',
        parentId: 'r',
        type: TodoType.note,
      );

      await mount(
        tester,
        rootsByCategory: {
          Category.work: [root],
        },
        childrenByParent: {
          'r': [childNote],
        },
        allTodos: [root, childNote],
      );

      await openNotesTab(tester);

      expect(find.byKey(const ValueKey('outline-note-cn')), findsOneWidget);
      expect(find.text('깊은 메모'), findsOneWidget);
    });

    testWidgets('note 없는 카테고리 섹션은 hide — note 있는 카테고리만 노출', (tester) async {
      final note = make(
        id: 'n',
        title: '개인 메모',
        category: Category.personalDev,
        type: TodoType.note,
      );

      await mount(
        tester,
        rootsByCategory: {
          Category.personalDev: [note],
        },
        allTodos: [note],
      );

      await openNotesTab(tester);

      // note 있는 카테고리(개인개발) 섹션만, 나머지 카테고리 섹션은 hide.
      // (체크리스트 탭은 keepAlive 로 offstage 잔존하므로 라벨 텍스트가 아니라
      //  메모 탭 전용 섹션 키로 확인.)
      expect(
        find.byKey(ValueKey('outline-note-section-${Category.personalDev.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('outline-note-section-${Category.work.id}')),
        findsNothing,
      );
      expect(find.text('개인 메모'), findsOneWidget);
    });
  });
}
