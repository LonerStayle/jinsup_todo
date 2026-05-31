import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/policies/recurrence_dedup_policy.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  Todo inst({
    required String id,
    required String seriesId,
    required DateTime dueAt,
    bool done = false,
    DateTime? createdAt,
  }) {
    final c = createdAt ?? dueAt;
    return Todo(
      id: id,
      title: '비타민',
      category: Category.daily,
      dueAt: dueAt,
      doneAt: done ? dueAt : null,
      createdAt: c,
      updatedAt: c,
      seriesId: seriesId,
    );
  }

  Todo plain(String id, DateTime dueAt) => Todo(
    id: id,
    title: '일반',
    category: Category.work,
    dueAt: dueAt,
    doneAt: null,
    createdAt: dueAt,
    updatedAt: dueAt,
  );

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('같은 시리즈 미체크 3건 → leader 1건만 + 숨김 2', () {
    final list = [
      inst(id: 'a', seriesId: 's', dueAt: d(2026, 1, 3)),
      inst(id: 'b', seriesId: 's', dueAt: d(2026, 1, 1)), // 가장 이른 = leader
      inst(id: 'c', seriesId: 's', dueAt: d(2026, 1, 2)),
    ];
    final r = RecurrenceDedupPolicy.dedupe(list);
    expect(r.visible.map((t) => t.id), ['b']);
    expect(r.hiddenCountBySeries['s'], 2);
  });

  test('leader 는 가장 이른 dueAt', () {
    final list = [
      inst(id: 'old', seriesId: 's', dueAt: d(2026, 1, 1)),
      inst(id: 'new', seriesId: 's', dueAt: d(2026, 1, 5)),
    ];
    final r = RecurrenceDedupPolicy.dedupe(list);
    expect(r.visible.single.id, 'old');
    expect(r.hiddenCountBySeries['s'], 1);
  });

  test('미체크 1건뿐인 시리즈는 그대로 (배지 없음)', () {
    final list = [inst(id: 'only', seriesId: 's', dueAt: d(2026, 1, 1))];
    final r = RecurrenceDedupPolicy.dedupe(list);
    expect(r.visible.single.id, 'only');
    expect(r.hiddenCountBySeries.containsKey('s'), isFalse);
  });

  test('체크된 인스턴스는 dedup 대상 아님 (모두 통과)', () {
    final list = [
      inst(id: 'done1', seriesId: 's', dueAt: d(2026, 1, 1), done: true),
      inst(id: 'done2', seriesId: 's', dueAt: d(2026, 1, 2), done: true),
      inst(id: 'undone', seriesId: 's', dueAt: d(2026, 1, 3)),
    ];
    final r = RecurrenceDedupPolicy.dedupe(list);
    // 체크 2건 + 미체크 1건(미체크 1건뿐이라 collapse 안 됨) → 전부 노출.
    expect(r.visible.map((t) => t.id), ['done1', 'done2', 'undone']);
    expect(r.hiddenCountBySeries, isEmpty);
  });

  test('비반복 Todo + 다른 시리즈 혼합 — 순서 보존', () {
    final list = [
      plain('p1', d(2026, 1, 1)),
      inst(id: 'x1', seriesId: 'A', dueAt: d(2026, 1, 1)),
      inst(id: 'x2', seriesId: 'A', dueAt: d(2026, 1, 2)),
      plain('p2', d(2026, 1, 1)),
      inst(id: 'y1', seriesId: 'B', dueAt: d(2026, 1, 1)),
    ];
    final r = RecurrenceDedupPolicy.dedupe(list);
    // A 시리즈는 leader(x1)만, B 는 1건이라 그대로. 순서 보존.
    expect(r.visible.map((t) => t.id), ['p1', 'x1', 'p2', 'y1']);
    expect(r.hiddenCountBySeries['A'], 1);
    expect(r.hiddenCountBySeries.containsKey('B'), isFalse);
  });

  test('빈 입력', () {
    final r = RecurrenceDedupPolicy.dedupe([]);
    expect(r.visible, isEmpty);
    expect(r.hiddenCountBySeries, isEmpty);
  });

  test('서로 다른 두 시리즈 각각 collapse', () {
    final list = [
      inst(id: 'a1', seriesId: 'A', dueAt: d(2026, 1, 1)),
      inst(id: 'a2', seriesId: 'A', dueAt: d(2026, 1, 2)),
      inst(id: 'b1', seriesId: 'B', dueAt: d(2026, 1, 1)),
      inst(id: 'b2', seriesId: 'B', dueAt: d(2026, 1, 2)),
      inst(id: 'b3', seriesId: 'B', dueAt: d(2026, 1, 3)),
    ];
    final r = RecurrenceDedupPolicy.dedupe(list);
    expect(r.visible.map((t) => t.id), ['a1', 'b1']);
    expect(r.hiddenCountBySeries['A'], 1);
    expect(r.hiddenCountBySeries['B'], 2);
  });
}
