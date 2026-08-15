// Tests for the celebration history persistence: entries round-trip through
// settings (newest first, one entry per id), the 24h cooldown suppresses
// replays, and re-celebrating moves an id back to the top.

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/data/repositories/settings_repository.dart';

import 'hive_test_harness.dart';

void main() {
  setUpAll(initTestHive);

  setUp(clearTestSettings);

  final repo = SettingsRepository.instance;

  test('starts with an empty history', () {
    expect(repo.celebrationHistory, isEmpty);
    expect(repo.wasCelebratedRecently('pro-unlock'), isFalse);
  });

  test('records celebrations newest-first, one entry per id', () async {
    await repo.markCelebrated('gallery-published');
    await repo.markCelebrated('pro-unlock');
    await repo.markCelebrated('gallery-published'); // second publish

    final history = repo.celebrationHistory;
    expect(history.length, 2, reason: 'one entry per celebration id');
    expect(history.first['id'], 'gallery-published');
    expect(history.last['id'], 'pro-unlock');
  });

  test('applies the cooldown per id', () async {
    expect(repo.wasCelebratedRecently('pro-unlock'), isFalse);
    await repo.markCelebrated('pro-unlock');
    expect(repo.wasCelebratedRecently('pro-unlock'), isTrue);
    // A different celebration is unaffected.
    expect(repo.wasCelebratedRecently('gallery-published'), isFalse);
  });

  test('re-celebrating an id moves it back to the top', () async {
    await repo.markCelebrated('pro-unlock');
    await repo.markCelebrated('gallery-published');
    expect(repo.celebrationHistory.first['id'], 'gallery-published');

    await repo.markCelebrated('pro-unlock');
    expect(repo.celebrationHistory.first['id'], 'pro-unlock');
  });
}
