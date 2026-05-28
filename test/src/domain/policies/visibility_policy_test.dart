import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/policies/visibility_policy.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  final now = DateTime(2026, 5, 27, 10, 0); // 오늘 = 2026-05-27, local 오전 10시

  Todo todo({
    DateTime? dueAt,
    DateTime? doneAt,
    DateTime? createdAt,
    TodoType type = TodoType.task,
    String? parentId,
  }) {
    final created = createdAt ?? DateTime(2026, 5, 25, 12);
    return Todo(
      id: 'id',
      title: '테스트',
      category: Category.daily,
      dueAt: dueAt,
      doneAt: doneAt,
      createdAt: created,
      updatedAt: created,
      calendarEventId: null,
      type: type,
      parentId: parentId,
    );
  }

  group('VisibilityPolicy.isVisibleToday — 미체크', () {
    test('dueAt 오늘 → true', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(dueAt: DateTime(2026, 5, 27, 15)),
          now,
        ),
        isTrue,
      );
    });

    test('dueAt 어제 → true (이월된 미체크는 오늘 화면에 보여야 함)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(dueAt: DateTime(2026, 5, 26, 9)),
          now,
        ),
        isTrue,
      );
    });

    test('dueAt 내일 → false (미래 일정은 오늘 화면에 안 보임)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(dueAt: DateTime(2026, 5, 28, 9)),
          now,
        ),
        isFalse,
      );
    });

    test('dueAt 내일 00:00 정확히 → false', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(dueAt: DateTime(2026, 5, 28, 0, 0)),
          now,
        ),
        isFalse,
      );
    });

    test('dueAt null + createdAt 어제 → true (effective = createdAt)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(createdAt: DateTime(2026, 5, 26, 11)),
          now,
        ),
        isTrue,
      );
    });

    test('dueAt null + createdAt 내일 → false (미래에 생성된 todo)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(createdAt: DateTime(2026, 5, 28, 11)),
          now,
        ),
        isFalse,
      );
    });
  });

  group('VisibilityPolicy.isVisibleToday — 체크됨', () {
    test('doneAt 오늘 → true (체크한 당일은 visible)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(doneAt: DateTime(2026, 5, 27, 14)),
          now,
        ),
        isTrue,
      );
    });

    test('doneAt 오늘 23:59 → true', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(doneAt: DateTime(2026, 5, 27, 23, 59)),
          now,
        ),
        isTrue,
      );
    });

    test('doneAt 어제 → false (당일 자정 지나면 hide)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(doneAt: DateTime(2026, 5, 26, 22)),
          now,
        ),
        isFalse,
      );
    });

    test('doneAt 어제 23:59, now 오늘 00:00 → false', () {
      final midnight = DateTime(2026, 5, 27, 0, 0);
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(doneAt: DateTime(2026, 5, 26, 23, 59)),
          midnight,
        ),
        isFalse,
      );
    });

    test('doneAt 오늘 직전 (23:59), now 다음날 00:01 → false (자정 지나서 hide)', () {
      final nextDay = DateTime(2026, 5, 28, 0, 1);
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(doneAt: DateTime(2026, 5, 27, 23, 59)),
          nextDay,
        ),
        isFalse,
      );
    });
  });

  group('VisibilityPolicy.isVisibleToday — v1.1 note 분리', () {
    test('note 타입은 dueAt 가 오늘이어도 today 화면에 안 보임', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(type: TodoType.note, dueAt: DateTime(2026, 5, 27, 15)),
          now,
        ),
        isFalse,
        reason: 'note 는 today 에서 제외 — outline / 카테고리 탭 전용',
      );
    });

    test('note 타입은 createdAt 어제여도 today 에 안 보임 (carryover 차단)', () {
      expect(
        VisibilityPolicy.isVisibleToday(
          todo(type: TodoType.note, createdAt: DateTime(2026, 5, 26, 11)),
          now,
        ),
        isFalse,
      );
    });

    test('동일 effective date 의 task 는 visible — type 만이 결정 인자임을 확인', () {
      final t = todo(type: TodoType.task, dueAt: DateTime(2026, 5, 27, 15));
      final n = todo(type: TodoType.note, dueAt: DateTime(2026, 5, 27, 15));
      expect(VisibilityPolicy.isVisibleToday(t, now), isTrue);
      expect(VisibilityPolicy.isVisibleToday(n, now), isFalse);
    });

    test('자식 (parentId set) 인 task 도 자기 자신만 평가 — 부모 무관', () {
      // 정책 함수는 단일 todo 만 받으므로 부모-자식 관계와 무관하게 평가된다.
      // 자식이 미체크 + 어제 → visible (= 이월). 부모 collection 영향 없음을 명시.
      final child = todo(
        type: TodoType.task,
        dueAt: DateTime(2026, 5, 26, 9),
        parentId: 'some-parent',
      );
      expect(VisibilityPolicy.isVisibleToday(child, now), isTrue);
    });
  });
}
