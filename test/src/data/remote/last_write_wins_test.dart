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
}
