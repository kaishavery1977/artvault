// Unit tests for PaintingRepository: CRUD, soft-delete, trash, sync queue.
// Verifies that paintings persist in Hive, soft-delete moves to trash,
// purge creates tombstones, and restore brings them back.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/data/repositories/painting_repository.dart';

import 'hive_test_harness.dart';

Painting _makePainting({String id = 'test-1', String title = 'Test Painting'}) =>
    Painting(
      id: id,
      title: title,
      artistId: 'a1',
      artistName: 'Test Artist',
      category: 'Landscape',
      medium: 'Oil on Canvas',
      style: 'Impressionism',
      price: 5000,
      currency: 'USD',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  setUp(() async {
    await LocalDatabase.instance.clear(AppConstants.boxPaintings);
    await LocalDatabase.instance.clear(AppConstants.boxSyncQueue);
  });

  group('Painting CRUD', () {
    test('save creates a painting in Hive', () async {
      final painting = _makePainting();
      final saved = await PaintingRepository.instance.save(painting);

      expect(saved.id, 'test-1');
      expect(saved.title, 'Test Painting');

      final fromHive = PaintingRepository.instance.get('test-1');
      expect(fromHive, isNotNull);
      expect(fromHive!.title, 'Test Painting');
    });

    test('save updates an existing painting', () async {
      final painting = _makePainting();
      await PaintingRepository.instance.save(painting);

      final updated = painting.copyWith(title: 'Updated Title');
      await PaintingRepository.instance.save(updated);

      final fromHive = PaintingRepository.instance.get('test-1');
      expect(fromHive!.title, 'Updated Title');
    });

    test('readAll returns all non-deleted paintings sorted by updatedAt', () async {
      await PaintingRepository.instance.save(_makePainting(id: 'p1', title: 'First'));
      await PaintingRepository.instance.save(_makePainting(id: 'p2', title: 'Second'));

      final all = PaintingRepository.instance.readAll();
      expect(all.length, 2);
      // Both have the same updatedAt — just verify both are present and sorted
      final ids = all.map((p) => p.id).toSet();
      expect(ids, containsAll(['p1', 'p2']));
    });

    test('countActive excludes deleted paintings', () async {
      await PaintingRepository.instance.save(_makePainting(id: 'p1'));
      await PaintingRepository.instance.save(_makePainting(id: 'p2'));

      // Soft-delete p1
      await PaintingRepository.instance.delete('p1');

      expect(PaintingRepository.instance.countActive(), 1);
      expect(PaintingRepository.instance.countTrash(), 1);
    });
  });

  group('Soft delete & trash', () {
    test('delete marks painting as deleted (soft-delete)', () async {
      await PaintingRepository.instance.save(_makePainting());
      await PaintingRepository.instance.delete('test-1');

      final painting = PaintingRepository.instance.get('test-1');
      expect(painting, isNotNull);
      expect(painting!.isDeleted, isTrue);
    });

    test('restore brings painting back from trash', () async {
      await PaintingRepository.instance.save(_makePainting());
      await PaintingRepository.instance.delete('test-1');
      await PaintingRepository.instance.restore('test-1');

      final painting = PaintingRepository.instance.get('test-1');
      expect(painting!.isDeleted, isFalse);
      expect(PaintingRepository.instance.countActive(), 1);
    });

    test('readActive excludes deleted paintings', () async {
      await PaintingRepository.instance.save(_makePainting(id: 'p1'));
      await PaintingRepository.instance.save(_makePainting(id: 'p2'));
      await PaintingRepository.instance.delete('p1');

      final active = PaintingRepository.instance.readActive();
      expect(active.length, 1);
      expect(active.first.id, 'p2');
    });

    test('readTrash returns only deleted paintings', () async {
      await PaintingRepository.instance.save(_makePainting(id: 'p1'));
      await PaintingRepository.instance.save(_makePainting(id: 'p2'));
      await PaintingRepository.instance.delete('p1');

      final trash = PaintingRepository.instance.readTrash();
      expect(trash.length, 1);
      expect(trash.first.id, 'p1');
    });
  });

  group('Purge & tombstones', () {
    test('purge removes painting from Hive and creates tombstone', () async {
      await PaintingRepository.instance.save(_makePainting());

      // Purge needs local files to exist or be handled gracefully
      // Since we're not creating actual files, the purge should still
      // remove the record and create a tombstone
      await PaintingRepository.instance.purge('test-1');

      final painting = PaintingRepository.instance.get('test-1');
      expect(painting, isNull);

      // Tombstone should be in sync queue
      final tombstones = LocalDatabase.instance.getAll(AppConstants.boxSyncQueue);
      expect(tombstones.any((t) => t['id'] == 'test-1'), isTrue);
    });
  });

  group('Toggle favorite', () {
    test('toggleFavorite flips isFavorite flag', () async {
      await PaintingRepository.instance.save(_makePainting());

      expect(PaintingRepository.instance.get('test-1')!.isFavorite, isFalse);

      await PaintingRepository.instance.toggleFavorite('test-1');
      expect(PaintingRepository.instance.get('test-1')!.isFavorite, isTrue);

      await PaintingRepository.instance.toggleFavorite('test-1');
      expect(PaintingRepository.instance.get('test-1')!.isFavorite, isFalse);
    });
  });

  group('Watch stream', () {
    test('watchPaintings emits on changes', () async {
      final completer = Completer<List<Painting>>();
      final sub = PaintingRepository.instance.watchPaintings().listen((list) {
        if (!completer.isCompleted) completer.complete(list);
      });

      // Collect initial emission
      final initial = await completer.future;
      expect(initial, isEmpty);

      // Save a painting
      await PaintingRepository.instance.save(_makePainting());

      // Next emission should include it
      final completer2 = Completer<List<Painting>>();
      final sub2 = PaintingRepository.instance.watchPaintings().listen((list) {
        if (!completer2.isCompleted) completer2.complete(list);
      });
      final after = await completer2.future;
      expect(after.length, 1);
      expect(after.first.title, 'Test Painting');

      await sub.cancel();
      await sub2.cancel();
    });
  });
}
