import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/calendar/calendar_service.dart';

void main() {
  test('GoogleAuthService 미설정 → calendarServiceProvider == null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(calendarServiceProvider), isNull);
  });

  Todo make({
    DateTime? dueAt,
    DateTime? endAt,
    bool isAllDay = false,
    String timeAnchor = 'start',
  }) => Todo(
    id: 'x',
    title: '제목',
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

  group('fast-tasks — buildEvent 매핑', () {
    test('하루종일 → all-day 이벤트 (start.date / end.date = 종료+1일)', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final e = CalendarService.buildEvent(
        make(dueAt: DateTime(2026, 5, 27), isAllDay: true),
      );
      expect(e.start!.date, DateTime(2026, 5, 27));
      expect(e.start!.dateTime, isNull);
      expect(e.end!.date, DateTime(2026, 5, 28)); // exclusive 다음날
    });

    test('단일 시작시간 → 1시간 timed 이벤트', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final e = CalendarService.buildEvent(
        make(dueAt: DateTime.utc(2026, 5, 27, 14, 0)),
      );
      expect(e.start!.dateTime, isNotNull);
      expect(e.start!.date, isNull);
      expect(
        e.end!.dateTime!.difference(e.start!.dateTime!),
        const Duration(hours: 1),
      );
    });

    test('단일 마감시간 → 1시간 timed 이벤트 (anchor 는 표시용)', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final e = CalendarService.buildEvent(
        make(dueAt: DateTime.utc(2026, 5, 27, 18, 0), timeAnchor: 'end'),
      );
      expect(e.start!.dateTime, isNotNull);
      expect(
        e.end!.dateTime!.difference(e.start!.dateTime!),
        const Duration(hours: 1),
      );
    });

    test('기간 + 하루종일 → all-day (end.date = 종료+1일)', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final e = CalendarService.buildEvent(
        make(
          dueAt: DateTime(2026, 5, 27),
          endAt: DateTime(2026, 5, 30),
          isAllDay: true,
        ),
      );
      expect(e.start!.date, DateTime(2026, 5, 27));
      expect(e.end!.date, DateTime(2026, 5, 31));
    });

    test('기간 + 시간 → start.dateTime=dueAt, end.dateTime=endAt', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final e = CalendarService.buildEvent(
        make(
          dueAt: DateTime.utc(2026, 5, 27, 9, 0),
          endAt: DateTime.utc(2026, 5, 27, 18, 30),
        ),
      );
      expect(e.start!.dateTime!.toUtc(), DateTime.utc(2026, 5, 27, 9, 0));
      expect(e.end!.dateTime!.toUtc(), DateTime.utc(2026, 5, 27, 18, 30));
    });
  });
}
