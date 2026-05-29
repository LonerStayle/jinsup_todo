import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/date_format.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  Todo make({
    DateTime? dueAt,
    DateTime? endAt,
    bool isAllDay = false,
    String timeAnchor = 'start',
  }) => Todo(
    id: 'x',
    title: 't',
    category: Category.work,
    dueAt: dueAt,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
    endAt: endAt,
    isAllDay: isAllDay,
    timeAnchor: timeAnchor,
  );

  group('TodoDateMode 도출', () {
    test('dueAt 없음 → none', () {
      expect(make().dateMode, TodoDateMode.none);
    });
    test('isAllDay → allDay', () {
      expect(
        make(dueAt: DateTime(2026, 5, 27), isAllDay: true).dateMode,
        TodoDateMode.allDay,
      );
    });
    test('시간 + start → startTime', () {
      expect(
        make(dueAt: DateTime(2026, 5, 27, 14, 30)).dateMode,
        TodoDateMode.startTime,
      );
    });
    test('시간 + end → endTime', () {
      expect(
        make(dueAt: DateTime(2026, 5, 27, 14, 30), timeAnchor: 'end').dateMode,
        TodoDateMode.endTime,
      );
    });
    test('endAt 있음 → range', () {
      expect(
        make(
          dueAt: DateTime(2026, 5, 27),
          endAt: DateTime(2026, 5, 30),
        ).dateMode,
        TodoDateMode.range,
      );
    });
  });

  group('TodoDateLabel.format — Task 1: 하루종일은 시간 미출력', () {
    test('none → null', () {
      expect(TodoDateLabel.format(make()), isNull);
    });

    test('하루종일 → "5/27" (00:00 / 오전 12:00 절대 미출력)', () {
      final label = TodoDateLabel.format(
        make(dueAt: DateTime(2026, 5, 27), isAllDay: true),
      );
      expect(label, '5/27');
      expect(label, isNot(contains(':')));
      expect(label, isNot(contains('00:00')));
      expect(label, isNot(contains('오전')));
    });

    test('시작시간 → "시작 5/27 14:30"', () {
      expect(
        TodoDateLabel.format(make(dueAt: DateTime(2026, 5, 27, 14, 30))),
        '시작 5/27 14:30',
      );
    });

    test('마감시간 → "마감 5/27 09:05"', () {
      expect(
        TodoDateLabel.format(
          make(dueAt: DateTime(2026, 5, 27, 9, 5), timeAnchor: 'end'),
        ),
        '마감 5/27 09:05',
      );
    });

    test('기간 + 하루종일 → "5/27 ~ 5/30" (시간 미출력)', () {
      final label = TodoDateLabel.format(
        make(
          dueAt: DateTime(2026, 5, 27),
          endAt: DateTime(2026, 5, 30),
          isAllDay: true,
        ),
      );
      expect(label, '5/27 ~ 5/30');
      expect(label, isNot(contains(':')));
    });

    test('기간 + 시간 → "5/27 09:00 ~ 5/30 18:30"', () {
      expect(
        TodoDateLabel.format(
          make(
            dueAt: DateTime(2026, 5, 27, 9, 0),
            endAt: DateTime(2026, 5, 30, 18, 30),
          ),
        ),
        '5/27 09:00 ~ 5/30 18:30',
      );
    });
  });
}
