// Offline-first hardening tests: prove the vault works with no network.
//
// In tests CloudBackend is never initialized (Firebase isn't configured), so
// `isReady` is false and every sync call is a safe no-op — exactly the
// no-network condition. These tests assert the Hive box remains the source
// of truth: writes land locally, reads never touch the cloud, trash/restore
// round-trips, purge leaves a tombstone, and dirty records stay dirty until
// a real sync can happen.

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/data/repositories/painting_repository.dart';
import 'package:artvault/data/remote/cloud_backend.dart';

import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  setUp(() async {
    await clearTestVault();
  });

  Painting makePainting({
    String? id,
    String title = 'Nocturne',
    bool isDeleted = false,
    bool needsSync = true,
    bool synced = false,
    bool isFavorite = false,
    DateTime? updatedAt,
  }) =>
      Painting(
        id: id ?? PaintingRepository.newId(),
        title: title,
        artistId: 'a1',
        artistName: 'Whistler',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: updatedAt ?? DateTime(2024, 1, 1),
        isDeleted: isDeleted,
        needsSync: needsSync,
        synced: synced,
        isFavorite: isFavorite,
      );

  test('cloud is not ready — this file genuinely exercises no-network mode',
      () {
    expect(CloudBackend.instance.isReady, isFalse);
  });

  test('save lands locally and stays dirty with no network', () async {
    final saved = await PaintingRepository.instance.save(makePainting());

    final fromDb = PaintingRepository.instance.get(saved.id);
    expect(fromDb, isNotNull);
    expect(fromDb!.title, 'Nocturne');
    // No cloud → the record must remain marked for sync.
    expect(fromDb.needsSync, isTrue);
    expect(fromDb.synced, isFalse);

    expect(PaintingRepository.instance.readAll(), hasLength(1));
    expect(PaintingRepository.instance.readActive(), hasLength(1));
  });

  test('reads and writes never require a network connection', () async {
    final repo = PaintingRepository.instance;
    final a =
        await repo.save(makePainting(title: 'A', updatedAt: DateTime(2024, 1, 1)));
    final b =
        await repo.save(makePainting(title: 'B', updatedAt: DateTime(2024, 1, 2)));

    // readAll sorts by updatedAt desc — later saves first.
    expect(repo.readAll().map((p) => p.id), [b.id, a.id]);
    expect(repo.get(a.id)!.title, 'A');

    // Update an existing record locally.
    final updated = a.copyWith(title: 'A (restored)', needsSync: true);
    await repo.save(updated);
    expect(repo.get(a.id)!.title, 'A (restored)');
  });

  test('delete moves to trash and restore brings it back', () async {
    final repo = PaintingRepository.instance;
    final painting = await repo.save(makePainting());

    await repo.delete(painting.id);
    expect(repo.get(painting.id)!.isDeleted, isTrue);
    expect(repo.readActive(), isEmpty);
    expect(repo.readTrash(), hasLength(1));
    expect(repo.countTrash(), 1);

    await repo.restore(painting.id);
    expect(repo.get(painting.id)!.isDeleted, isFalse);
    expect(repo.readActive(), hasLength(1));
    expect(repo.readTrash(), isEmpty);
  });

  test('purge removes the record and leaves a tombstone', () async {
    final repo = PaintingRepository.instance;
    final painting = await repo.save(makePainting());

    await repo.purge(painting.id);
    expect(repo.get(painting.id), isNull);
    expect(repo.readAll(), isEmpty);

    // The sync queue holds a purge tombstone so a later pull can't
    // resurrect the painting (offline purge protection).
    final tombstones =
        LocalDatabase.instance.getAll(AppConstants.boxSyncQueue);
    expect(tombstones, hasLength(1));
    expect(tombstones.single['id'], painting.id);
  });

  test('purge of an unknown id is a safe no-op', () async {
    await PaintingRepository.instance.purge('does-not-exist');
    expect(PaintingRepository.instance.readAll(), isEmpty);
  });

  test('toggleFavorite persists locally offline', () async {
    final repo = PaintingRepository.instance;
    final painting = await repo.save(makePainting());

    await repo.toggleFavorite(painting.id);
    expect(repo.get(painting.id)!.isFavorite, isTrue);

    await repo.toggleFavorite(painting.id);
    expect(repo.get(painting.id)!.isFavorite, isFalse);
  });

  test('syncNow with no network returns 0 and keeps records dirty',
      () async {
    final repo = PaintingRepository.instance;
    await repo.save(makePainting());
    await repo.save(makePainting(title: 'Second'));

    expect(await repo.syncNow(), 0);

    // No cloud → nothing synced, everything still pending.
    for (final p in repo.readAll()) {
      expect(p.needsSync, isTrue);
      expect(p.synced, isFalse);
    }
  });

  test('markSynced preserves the trash flag (no resurrection)', () {
    final trashed = makePainting(isDeleted: true, needsSync: true);
    final synced = trashed.markSynced();
    expect(synced.isDeleted, isTrue);
    expect(synced.needsSync, isFalse);
    expect(synced.synced, isTrue);
  });

  test('model survives a full JSON round-trip unchanged', () {
    final painting = makePainting(isDeleted: true, isFavorite: true);
    final restored = Painting.fromJson(painting.toJson());
    expect(restored.id, painting.id);
    expect(restored.title, painting.title);
    expect(restored.isDeleted, painting.isDeleted);
    expect(restored.isFavorite, painting.isFavorite);
    expect(restored.needsSync, painting.needsSync);
    expect(restored.updatedAt, painting.updatedAt);
  });
}
