import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/recurrence_materializer.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  DateTime dt(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime(y, m, d, h, min);

  Todo master({
    required RecurrenceRule rule,
    required DateTime dueAt,
    DateTime? endAt,
    DateTime? recurrenceEndAt,
    bool isAllDay = false,
    String id = 'm1',
  }) {
    return Todo(
      id: id,
      title: '반복 할일',
      category: Category.work,
      dueAt: dueAt,
      doneAt: null,
      createdAt: dueAt,
      updatedAt: dueAt,
      endAt: endAt,
      isAllDay: isAllDay,
      seriesId: id,
      recurrenceRule: rule.encode(),
      recurrenceEndAt: recurrenceEndAt,
      isSeriesMaster: true,
    );
  }

  final now = dt(2026, 1, 5, 12); // "오늘" = 1/5

  group('materializeDue — 기본 생성', () {
    test('매일: anchor~오늘 모든 발생일 생성 (anchor 포함)', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got.length, 5); // 1/1,1/2,1/3,1/4,1/5
      expect(got.map((t) => t.dueAt!.day), [1, 2, 3, 4, 5]);
      for (final t in got) {
        expect(t.seriesId, 'm1');
        expect(t.isSeriesMaster, isFalse);
        expect(t.recurrenceRule, isNull);
        expect(t.recurrenceEndAt, isNull);
        expect(t.calendarEventId, isNull);
        expect(t.category, Category.work);
      }
    });

    test('id 는 결정적 (seriesId#yyyymmdd)', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 4),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got.map((t) => t.id).toSet().length, got.length); // 유일
      expect(got.map((t) => t.id), ['m1#20260104', 'm1#20260105']);
      // 같은 입력 재호출 → 같은 id (결정적).
      final again = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(again.map((t) => t.id), got.map((t) => t.id));
    });
  });

  group('materializeDue — idempotency', () {
    test('이미 존재하는 발생일은 건너뜀', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final existing = {
        'm1': {dt(2026, 1, 1), dt(2026, 1, 2), dt(2026, 1, 3)},
      };
      final got = RecurrenceMaterializer.materializeDue([m], existing, now);
      expect(got.map((t) => t.dueAt!.day), [4, 5]);
    });

    test('전부 존재하면 빈 결과', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 4),
      );
      final existing = {
        'm1': {dt(2026, 1, 4), dt(2026, 1, 5)},
      };
      final got = RecurrenceMaterializer.materializeDue([m], existing, now);
      expect(got, isEmpty);
    });
  });

  group('materializeDue — 컷', () {
    test('종료일 이후 발생분은 생성 안 함', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
        recurrenceEndAt: dt(2026, 1, 3),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got.map((t) => t.dueAt!.day), [1, 2, 3]);
    });

    test('미래분(오늘 이후)은 제외', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(
        got.every((t) => !t.dueAt!.isAfter(dt(2026, 1, 5, 23, 59))),
        isTrue,
      );
      expect(got.any((t) => t.dueAt!.day == 6), isFalse);
    });

    test('anchor 가 미래면 아무것도 생성 안 함', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 2, 1),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got, isEmpty);
    });

    test('maxPerSeries 상한', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final got = RecurrenceMaterializer.materializeDue(
        [m],
        {},
        now,
        maxPerSeries: 3,
      );
      expect(got.length, 3);
    });
  });

  group('materializeDue — 패턴 복제', () {
    test('시각 유지 (09:30)', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 4, 9, 30),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      for (final t in got) {
        expect(t.dueAt!.hour, 9);
        expect(t.dueAt!.minute, 30);
      }
    });

    test('기간(range): endAt 길이 보존', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 4, 9, 0),
        endAt: dt(2026, 1, 4, 11, 0), // 2시간
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      for (final t in got) {
        expect(t.endAt, isNotNull);
        expect(t.endAt!.difference(t.dueAt!), const Duration(hours: 2));
      }
    });

    test('isAllDay 복제', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 4),
        isAllDay: true,
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got.every((t) => t.isAllDay), isTrue);
    });
  });

  group('materializeDue — 비대상 무시', () {
    test('마스터 아님(일반 Todo)은 무시', () {
      final plain = Todo(
        id: 'p',
        title: '일반',
        category: Category.work,
        dueAt: dt(2026, 1, 1),
        doneAt: null,
        createdAt: dt(2026, 1, 1),
        updatedAt: dt(2026, 1, 1),
      );
      final got = RecurrenceMaterializer.materializeDue([plain], {}, now);
      expect(got, isEmpty);
    });

    test('weekly 매주 월요일: 해당 요일만', () {
      // 1/5 가 월요일. anchor 1/5, now 1/5 → 1/5 한 건.
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.weekly),
        dueAt: dt(2026, 1, 5),
      );
      final got = RecurrenceMaterializer.materializeDue([m], {}, now);
      expect(got.length, 1);
      expect(got.first.dueAt!.day, 5);
    });
  });

  group('헬퍼', () {
    test('indexExistingInstanceDates: 인스턴스만 인덱싱, 마스터 제외', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final inst = Todo(
        id: 'i1',
        title: '반복 할일',
        category: Category.work,
        dueAt: dt(2026, 1, 2, 8),
        doneAt: null,
        createdAt: dt(2026, 1, 2),
        updatedAt: dt(2026, 1, 2),
        seriesId: 'm1',
      );
      final idx = RecurrenceMaterializer.indexExistingInstanceDates([m, inst]);
      expect(idx['m1'], {dt(2026, 1, 2)}); // 마스터의 anchor(1/1)은 제외
    });

    test('activeMasters: 마스터만', () {
      final m = master(
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: dt(2026, 1, 1),
      );
      final plain = Todo(
        id: 'p',
        title: '일반',
        category: Category.work,
        dueAt: dt(2026, 1, 1),
        doneAt: null,
        createdAt: dt(2026, 1, 1),
        updatedAt: dt(2026, 1, 1),
      );
      expect(RecurrenceMaterializer.activeMasters([m, plain]), [m]);
    });
  });
}
