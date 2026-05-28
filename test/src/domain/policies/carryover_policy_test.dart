import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/policies/carryover_policy.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  // 결정적 시점 — 모든 케이스는 이 [now] 기준.
  final now = DateTime(2026, 5, 27, 10, 0); // local: 2026-05-27 오전 10시

  Todo todo({
    DateTime? dueAt,
    DateTime? doneAt,
    DateTime? createdAt,
    Category category = Category.daily,
    TodoType type = TodoType.task,
    String? parentId,
  }) {
    final created = createdAt ?? DateTime(2026, 5, 25, 12);
    return Todo(
      id: 'id',
      title: '테스트',
      category: category,
      dueAt: dueAt,
      doneAt: doneAt,
      createdAt: created,
      updatedAt: created,
      calendarEventId: null,
      type: type,
      parentId: parentId,
    );
  }

  group('CarryoverPolicy.shouldCarryOverToday', () {
    test('dueAt 이 어제 + 미체크 → true (오늘로 이월)', () {
      final t = todo(dueAt: DateTime(2026, 5, 26, 15));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isTrue);
    });

    test('dueAt 이 오늘 0시 + 미체크 → false (이미 오늘)', () {
      final t = todo(dueAt: DateTime(2026, 5, 27, 0, 0));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isFalse);
    });

    test('dueAt 이 오늘 늦은 시각 + 미체크 → false', () {
      final t = todo(dueAt: DateTime(2026, 5, 27, 23, 59));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isFalse);
    });

    test('dueAt 이 내일 + 미체크 → false', () {
      final t = todo(dueAt: DateTime(2026, 5, 28, 9));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isFalse);
    });

    test('dueAt 이 어제 + 체크됨 → false (체크된 건 이월 X)', () {
      final t = todo(
        dueAt: DateTime(2026, 5, 26, 15),
        doneAt: DateTime(2026, 5, 26, 18),
      );
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isFalse);
    });

    test(
      'dueAt 이 null + createdAt 이 어제 + 미체크 → true (effective = createdAt)',
      () {
        final t = todo(createdAt: DateTime(2026, 5, 26, 11));
        expect(CarryoverPolicy.shouldCarryOverToday(t, now), isTrue);
      },
    );

    test('dueAt 이 null + createdAt 이 오늘 + 미체크 → false', () {
      final t = todo(createdAt: DateTime(2026, 5, 27, 8));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isFalse);
    });

    test('자정 직후 (now=00:01) + dueAt 어제 23:59 + 미체크 → true', () {
      final midnightish = DateTime(2026, 5, 27, 0, 1);
      final t = todo(dueAt: DateTime(2026, 5, 26, 23, 59));
      expect(CarryoverPolicy.shouldCarryOverToday(t, midnightish), isTrue);
    });

    test('자정 직전 (now=23:59) + dueAt 오늘 00:01 + 미체크 → false', () {
      final lateNight = DateTime(2026, 5, 27, 23, 59);
      final t = todo(dueAt: DateTime(2026, 5, 27, 0, 1));
      expect(CarryoverPolicy.shouldCarryOverToday(t, lateNight), isFalse);
    });

    test('아주 오래된 미체크 (3일 전) + dueAt 없음 + createdAt 그날 → true', () {
      final t = todo(createdAt: DateTime(2026, 5, 24, 8));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isTrue);
    });
  });

  group('CarryoverPolicy — v1.1 note 분리', () {
    test('note 타입은 어제 created 여도 carryover 대상 X', () {
      final n = todo(type: TodoType.note, createdAt: DateTime(2026, 5, 26, 9));
      expect(
        CarryoverPolicy.shouldCarryOverToday(n, now),
        isFalse,
        reason: 'note 는 체크 개념이 없어 이월 자체가 성립 X',
      );
    });

    test('note 타입 + dueAt 어제 + 미체크 → 그래도 false', () {
      final n = todo(type: TodoType.note, dueAt: DateTime(2026, 5, 26, 15));
      expect(CarryoverPolicy.shouldCarryOverToday(n, now), isFalse);
    });

    test('같은 effective date 의 task 는 true — type 만이 결정 인자임을 확인', () {
      final t = todo(type: TodoType.task, dueAt: DateTime(2026, 5, 26, 15));
      final n = todo(type: TodoType.note, dueAt: DateTime(2026, 5, 26, 15));
      expect(CarryoverPolicy.shouldCarryOverToday(t, now), isTrue);
      expect(CarryoverPolicy.shouldCarryOverToday(n, now), isFalse);
    });

    test('자식 (parentId set) task 도 자기 자신만 평가 — 부모 무관', () {
      final child = todo(
        type: TodoType.task,
        parentId: 'parent-x',
        dueAt: DateTime(2026, 5, 26, 9),
      );
      expect(CarryoverPolicy.shouldCarryOverToday(child, now), isTrue);
    });
  });
}
