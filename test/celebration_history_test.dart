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

  test('caps the history at 20 entries, newest first', () async {
    for (var i = 0; i < 25; i++) {
      await repo.markCelebrated('celebration-$i');
    }

    final history = repo.celebrationHistory;
    expect(history.length, 20, reason: 'history is capped at 20 entries');
    // Newest entry first; the oldest beyond the cap is dropped.
    expect(history.first['id'], 'celebration-24');
    expect(history.last['id'], 'celebration-5');
  });

  test('rapid successive celebrations stay newest-first', () async {
    // Microsecond timestamps keep ordering deterministic even when marks
    // fire back-to-back in the same millisecond.
    for (var i = 0; i < 5; i++) {
      await repo.markCelebrated('tie-$i');
    }
    final history = repo.celebrationHistory;
    expect(history.length, 5);
    // The most recently marked celebration sorts first, every time.
    expect(history.first['id'], 'tie-4');
    expect(history.last['id'], 'tie-0');
  });
}

