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

  test('updated_at 동률 → idempotent (remote 채택, true)', () {
    final t = DateTime.utc(2026, 5, 27, 10);
    expect(LastWriteWins.remoteWins(at(t), at(t)), isTrue);
  });
}
