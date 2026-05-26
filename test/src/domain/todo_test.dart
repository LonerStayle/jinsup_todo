import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  // 결정적 시간 / id 주입 — DateTime.now / Uuid().v4 가 호출되지 않게 한다.
  DateTime fixedNow() => DateTime.utc(2026, 5, 27, 9, 0, 0);
  String fixedId() => '00000000-0000-4000-8000-000000000001';

  group('Todo.create', () {
    test('필수 필드 + dueAt null, doneAt null, calendarEventId null 로 초기화', () {
      final t = Todo.create(
        title: '회사 보고서',
        category: Category.work,
        now: fixedNow,
        idGen: fixedId,
      );

      expect(t.id, fixedId());
      expect(t.title, '회사 보고서');
      expect(t.category, Category.work);
      expect(t.dueAt, isNull);
      expect(t.doneAt, isNull);
      expect(t.createdAt, fixedNow());
      expect(t.updatedAt, fixedNow());
      expect(t.calendarEventId, isNull);
      expect(t.isDone, isFalse);
    });

    test('dueAt 전달 시 보존', () {
      final due = DateTime.utc(2026, 5, 28, 14, 0);
      final t = Todo.create(
        title: '미팅',
        category: Category.work,
        dueAt: due,
        now: fixedNow,
        idGen: fixedId,
      );
      expect(t.dueAt, due);
    });
  });

  group('Todo.toggleDone', () {
    test('미체크 → 체크: doneAt 가 [now] 가 되고 updatedAt 도 갱신', () {
      final t = Todo.create(
        title: 'x',
        category: Category.daily,
        now: () => DateTime.utc(2026, 5, 1),
        idGen: fixedId,
      );
      final later = DateTime.utc(2026, 5, 27, 10);
      final toggled = t.toggleDone(now: () => later);

      expect(toggled.isDone, isTrue);
      expect(toggled.doneAt, later);
      expect(toggled.updatedAt, later);
      // 다른 필드는 보존
      expect(toggled.id, t.id);
      expect(toggled.title, t.title);
      expect(toggled.createdAt, t.createdAt);
    });

    test('체크 → 미체크: doneAt 가 null 로, updatedAt 은 갱신', () {
      final created = DateTime.utc(2026, 5, 1);
      final base = Todo.create(
        title: 'x',
        category: Category.daily,
        now: () => created,
        idGen: fixedId,
      );
      final firstToggle = DateTime.utc(2026, 5, 2);
      final done = base.toggleDone(now: () => firstToggle);

      final undoTime = DateTime.utc(2026, 5, 3);
      final undone = done.toggleDone(now: () => undoTime);
      expect(undone.isDone, isFalse);
      expect(undone.doneAt, isNull);
      expect(undone.updatedAt, undoTime);
    });
  });

  test('withCalendarEvent 가 eventId 와 updatedAt 만 변경', () {
    final t = Todo.create(
      title: 'x',
      category: Category.idea,
      now: fixedNow,
      idGen: fixedId,
    );
    final later = DateTime.utc(2026, 5, 28);
    final linked = t.withCalendarEvent('event-123', now: () => later);
    expect(linked.calendarEventId, 'event-123');
    expect(linked.updatedAt, later);
    expect(linked.id, t.id);
    expect(linked.title, t.title);
    expect(linked.createdAt, t.createdAt);
  });

  group('JSON round-trip', () {
    test('완전 필드 (dueAt / doneAt / calendarEventId 모두 채움)', () {
      final original = Todo(
        id: 'abc',
        title: 'PR 리뷰',
        category: Category.personalDev,
        dueAt: DateTime.utc(2026, 5, 28, 13),
        doneAt: DateTime.utc(2026, 5, 28, 18),
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 18),
        calendarEventId: 'evt-xyz',
      );
      final json = original.toJson();
      // 카테고리는 [Category.id] 그대로 직렬화 — @JsonValue('personal_dev') 보장.
      expect(json['category'], 'personal_dev');

      final restored = Todo.fromJson(json);
      expect(restored, original);
    });

    test('nullable 필드 누락 round-trip', () {
      final original = Todo.create(
        title: '아이디어',
        category: Category.idea,
        now: fixedNow,
        idGen: fixedId,
      );
      final restored = Todo.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  test('Equality (freezed) — 동일 필드는 ==', () {
    final a = Todo.create(
      title: 'a',
      category: Category.daily,
      now: fixedNow,
      idGen: fixedId,
    );
    final b = Todo.create(
      title: 'a',
      category: Category.daily,
      now: fixedNow,
      idGen: fixedId,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
