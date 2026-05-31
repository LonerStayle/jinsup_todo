import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/domain/recurrence.dart';

void main() {
  // 테스트 날짜는 local 기준 date-only 로 다룬다.
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('nextOccurrence — daily', () {
    test('매일(interval 1): 다음날', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily);
      final anchor = d(2026, 1, 1);
      expect(r.nextOccurrence(d(2026, 1, 1), anchor), d(2026, 1, 2));
      expect(r.nextOccurrence(d(2026, 1, 5), anchor), d(2026, 1, 6));
    });

    test('3일마다: anchor 정렬 유지', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 3);
      final anchor = d(2026, 1, 1); // 1,4,7,10...
      expect(r.nextOccurrence(d(2026, 1, 1), anchor), d(2026, 1, 4));
      expect(r.nextOccurrence(d(2026, 1, 2), anchor), d(2026, 1, 4));
      expect(r.nextOccurrence(d(2026, 1, 4), anchor), d(2026, 1, 7));
    });

    test('after 가 anchor 이전이면 anchor 부터', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 2);
      final anchor = d(2026, 1, 10);
      expect(r.nextOccurrence(d(2026, 1, 1), anchor), d(2026, 1, 10));
    });
  });

  group('nextOccurrence — weekly', () {
    test('매주(byWeekday 비움): anchor 요일 유지', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.weekly);
      final anchor = d(2026, 1, 5); // 월요일
      expect(anchor.weekday, DateTime.monday);
      expect(r.nextOccurrence(anchor, anchor), d(2026, 1, 12));
    });

    test('2주마다 월/수: 격주 주의 해당 요일만', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const {DateTime.monday, DateTime.wednesday},
      );
      final anchor = d(2026, 1, 5); // 월 (week 0)
      // week 0: 1/5(월), 1/7(수). week 1 skip. week 2: 1/19(월), 1/21(수)
      expect(r.nextOccurrence(d(2026, 1, 5), anchor), d(2026, 1, 7));
      expect(r.nextOccurrence(d(2026, 1, 7), anchor), d(2026, 1, 19));
      expect(r.nextOccurrence(d(2026, 1, 19), anchor), d(2026, 1, 21));
    });

    test('isOccurrenceOn: 격주 off 주는 false', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const {DateTime.monday},
      );
      final anchor = d(2026, 1, 5);
      expect(r.isOccurrenceOn(d(2026, 1, 5), anchor), isTrue);
      expect(r.isOccurrenceOn(d(2026, 1, 12), anchor), isFalse); // off week
      expect(r.isOccurrenceOn(d(2026, 1, 19), anchor), isTrue);
    });
  });

  group('nextOccurrence — monthly (월말 클램프)', () {
    test('매월 같은 일', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.monthly);
      final anchor = d(2026, 1, 15);
      expect(r.nextOccurrence(d(2026, 1, 15), anchor), d(2026, 2, 15));
    });

    test('매월 31일 → 31일 없는 달은 말일로 클램프', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.monthly);
      final anchor = d(2026, 1, 31);
      // 2월은 28일(2026 평년)
      expect(r.nextOccurrence(d(2026, 1, 31), anchor), d(2026, 2, 28));
      // 3월은 31일 복귀
      expect(r.nextOccurrence(d(2026, 2, 28), anchor), d(2026, 3, 31));
      // 4월은 30일
      expect(r.nextOccurrence(d(2026, 3, 31), anchor), d(2026, 4, 30));
    });

    test('2개월마다', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.monthly, interval: 2);
      final anchor = d(2026, 1, 10);
      expect(r.nextOccurrence(d(2026, 1, 10), anchor), d(2026, 3, 10));
    });
  });

  group('nextOccurrence — yearly (윤년 2/29)', () {
    test('매년 같은 월/일', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.yearly);
      final anchor = d(2026, 5, 31);
      expect(r.nextOccurrence(d(2026, 5, 31), anchor), d(2027, 5, 31));
    });

    test('매년 2/29 → 평년은 2/28', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.yearly);
      final anchor = d(2024, 2, 29); // 2024 윤년
      expect(r.nextOccurrence(d(2024, 2, 29), anchor), d(2025, 2, 28));
      expect(
        r.nextOccurrence(d(2027, 12, 31), anchor),
        d(2028, 2, 29),
      ); // 윤년 복귀
    });
  });

  group('occurrencesUntil', () {
    test('매일 5일치', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily);
      final anchor = d(2026, 1, 1);
      expect(r.occurrencesUntil(anchor, d(2026, 1, 5)), [
        d(2026, 1, 1),
        d(2026, 1, 2),
        d(2026, 1, 3),
        d(2026, 1, 4),
        d(2026, 1, 5),
      ]);
    });

    test('maxCount 가드', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily);
      final anchor = d(2026, 1, 1);
      final got = r.occurrencesUntil(anchor, d(2030, 1, 1), maxCount: 3);
      expect(got.length, 3);
    });

    test('매월 31일 1년치는 말일 클램프 포함', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.monthly);
      final anchor = d(2026, 1, 31);
      final got = r.occurrencesUntil(anchor, d(2026, 12, 31));
      expect(got.first, d(2026, 1, 31));
      expect(got.contains(d(2026, 2, 28)), isTrue);
      expect(got.contains(d(2026, 4, 30)), isTrue);
    });
  });

  group('encode / decode 왕복', () {
    test('daily', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 3);
      expect(r.encode(), 'FREQ=DAILY;INTERVAL=3');
      expect(RecurrenceRule.decode(r.encode()), r);
    });

    test('weekly + byday 정렬', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const {DateTime.wednesday, DateTime.monday},
      );
      expect(r.encode(), 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE');
      expect(RecurrenceRule.decode(r.encode()), r);
    });

    test('monthly / yearly', () {
      for (final f in [RecurrenceFreq.monthly, RecurrenceFreq.yearly]) {
        final r = RecurrenceRule(freq: f, interval: 2);
        expect(RecurrenceRule.decode(r.encode()), r);
      }
    });

    test('잘못된 문자열은 FormatException', () {
      expect(() => RecurrenceRule.decode('INTERVAL=2'), throwsFormatException);
    });
  });

  group('toRRule', () {
    test('UNTIL 없음', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.weekly);
      expect(r.toRRule(null), 'RRULE:FREQ=WEEKLY;INTERVAL=1');
    });

    test('UNTIL 은 UTC stamp', () {
      final r = const RecurrenceRule(freq: RecurrenceFreq.daily);
      final until = DateTime.utc(2026, 12, 31, 0, 0, 0);
      expect(
        r.toRRule(until),
        'RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20261231T000000Z',
      );
    });

    test('weekly byday 포함', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        byWeekday: const {DateTime.monday},
      );
      expect(r.toRRule(null), 'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO');
    });
  });

  group('describe (한국어 요약)', () {
    test('n=1 주기별', () {
      expect(const RecurrenceRule(freq: RecurrenceFreq.daily).describe(), '매일');
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.weekly).describe(),
        '매주',
      );
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.monthly).describe(),
        '매월',
      );
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.yearly).describe(),
        '매년',
      );
    });

    test('n>1 간격 — 매월은 "개월마다"', () {
      expect(
        const RecurrenceRule(
          freq: RecurrenceFreq.daily,
          interval: 3,
        ).describe(),
        '3일마다',
      );
      expect(
        const RecurrenceRule(
          freq: RecurrenceFreq.monthly,
          interval: 2,
        ).describe(),
        '2개월마다',
      );
    });

    test('weekly + 요일', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const {DateTime.monday, DateTime.wednesday},
      );
      expect(r.describe(), '2주마다 (월·수)');
    });

    test('종료일 덧붙임', () {
      expect(
        const RecurrenceRule(
          freq: RecurrenceFreq.monthly,
        ).describe(until: DateTime(2026, 12, 31)),
        '매월 · 2026.12.31 까지',
      );
    });
  });

  group('동등성', () {
    test('같은 규칙은 ==', () {
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 2),
        const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 2),
      );
    });

    test('byWeekday 순서 무관', () {
      expect(
        RecurrenceRule(
          freq: RecurrenceFreq.weekly,
          byWeekday: const {DateTime.monday, DateTime.friday},
        ),
        RecurrenceRule(
          freq: RecurrenceFreq.weekly,
          byWeekday: const {DateTime.friday, DateTime.monday},
        ),
      );
    });
  });
}
