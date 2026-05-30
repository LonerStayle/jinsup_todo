import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/remote/last_write_wins.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  Todo at(DateTime updated, {String title = 'x'}) => Todo(
    id: 'a',
    title: title,
    category: Category.daily,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 1),
    updatedAt: updated,
    calendarEventId: null,
  );

  test('local 이 null → remote 채택', () {
    final remote = at(DateTime.utc(2026, 5, 27, 10));
    expect(LastWriteWins.remoteWins(null, remote), isTrue);
  });

  test('remote.updatedAt > local.updatedAt → remote 채택', () {
    final local = at(DateTime.utc(2026, 5, 27, 9));
    final remote = at(DateTime.utc(2026, 5, 27, 10), title: 'newer');
    expect(LastWriteWins.remoteWins(local, remote), isTrue);
  });

  test('remote.updatedAt < local.updatedAt → remote stale, skip', () {
    final local = at(DateTime.utc(2026, 5, 27, 12));
    final remote = at(DateTime.utc(2026, 5, 27, 9), title: 'older');
    expect(LastWriteWins.remoteWins(local, remote), isFalse);
  });

  test('updated_at 동률 → local 채택 (self-overwrite 방지). strict > 정책', () {
    final t = DateTime.utc(2026, 5, 27, 10);
    expect(
      LastWriteWins.remoteWins(at(t), at(t)),
      isFalse,
      reason: '같은 ms 의 self-receive 가 local 을 stomp 하면 안 됨',
    );
  });

  test(
    'ms 동률이지만 다른 client 의 변경 (다른 title) → local 우선 — 다음 broadcast 에서 일치 회복',
    () {
      // 동시에 두 client 가 다른 변경 → 한쪽 local 이 우선 보존. 후속 broadcast 가
      // 새 ms 로 정렬을 회복한다는 가정 (eventually consistent).
      final t = DateTime.utc(2026, 5, 27, 10);
      final local = at(t, title: 'local-edit');
      final remote = at(t, title: 'remote-edit');
      expect(LastWriteWins.remoteWins(local, remote), isFalse);
    },
  );

  test('같은 instant 인데 local 은 로컬-naive, remote 는 UTC → remote 가 이기면 안 됨 '
      '(UTC 정규화 회귀)', () {
    // 회귀: 편집 직후 local updatedAt 이 로컬시간(Z 없음)으로 저장되고, Supabase
    // 왕복본은 UTC(Z) 라 동일 시각인데도 remote 가 timezone offset 만큼 "최신"으로
    // 오판되어 방금 쓴 값이 stale 원격으로 덮어써졌다. remoteWins 는 UTC 로 비교한다.
    final utc = DateTime.utc(2026, 5, 27, 10, 30);
    final localNaive = utc.toLocal(); // 동일 instant, 로컬 표현 (isUtc == false)
    final local = at(localNaive, title: 'just-edited');
    final remote = at(utc, title: 'echo');
    expect(
      LastWriteWins.remoteWins(local, remote),
      isFalse,
      reason: '같은 instant → 동률 → local 보존(skip)',
    );
  });
}
