// Regression tests for two user-reported bugs:
//
//  1. "After restore from the cloud the paintings show but the photos don't"
//     — a backup snapshot can carry metadata without image URLs, and a pull
//     refused to adopt the remote copy that HAS the URLs. Also, the upload
//     loop could misalign URLs when an earlier image was never mirrored.
//  2. "Profile edits aren't remembered after logging in again" — the locally
//     edited profile was replaced by the cloud copy on every login, so an
//     edit made when the cloud write failed was silently discarded.

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/data/repositories/auth_repository.dart';
import 'package:artvault/data/repositories/painting_repository.dart';
import 'package:artvault/data/remote/cloud_backend.dart';

import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  setUp(() async {
    await clearTestVault();
    await LocalDatabase.instance.box(AppConstants.boxProfile).clear();
  });

  Painting painting({
    String? id,
    String title = 'Nocturne',
    List<String> images = const ['/img/a.jpg', '/img/b.jpg'],
    List<String> imageUrls = const [],
    String coverImageUrl = '',
    DateTime? updatedAt,
  }) =>
      Painting(
        id: id ?? PaintingRepository.newId(),
        title: title,
        artistId: 'a1',
        artistName: 'Whistler',
        images: images,
        imageUrls: imageUrls,
        coverImageUrl: coverImageUrl,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: updatedAt ?? DateTime(2024, 1, 1),
      );

  group('photo repair after cloud restore', () {
    test('cloud is not ready — these tests exercise the no-network surface',
        () {
      expect(CloudBackend.instance.isReady, isFalse);
    });

    test('alignUrls pads so images[i] ↔ urls[i] stay aligned', () {
      // One existing URL must keep its position, not be pushed by later ones.
      final aligned = PaintingRepository.alignUrls(
        ['/a.jpg', '/b.jpg', '/c.jpg'],
        ['urlA'],
      );
      expect(aligned, ['urlA', '', '']);
    });

    test('alignUrls keeps a full mapping untouched', () {
      final aligned = PaintingRepository.alignUrls(
        ['/a.jpg', '/b.jpg'],
        ['urlA', 'urlB'],
      );
      expect(aligned, ['urlA', 'urlB']);
    });

    test('alignUrls does not truncate a longer existing list', () {
      final aligned = PaintingRepository.alignUrls(
        ['/a.jpg'],
        ['urlA', 'urlB'],
      );
      expect(aligned, ['urlA', 'urlB']);
    });

    test('shouldAdoptRemote adopts a remote copy that has URLs local lacks',
        () {
      final local = painting(imageUrls: const [], coverImageUrl: '');
      // Same timestamp — a restore snapshot vs the authoritative live doc.
      final remote = painting(
        id: local.id,
        imageUrls: const ['https://cdn/x.jpg'],
        coverImageUrl: 'https://cdn/x.jpg',
        updatedAt: local.updatedAt,
      );
      expect(
        PaintingRepository.shouldAdoptRemote(local, remote),
        isTrue,
        reason: 'local has no mirrors but remote does — adopt to repair',
      );
    });

    test('shouldAdoptRemote does not overwrite local URLs with older data',
        () {
      final local = painting(
        imageUrls: const ['https://cdn/new.jpg'],
        coverImageUrl: 'https://cdn/new.jpg',
        updatedAt: DateTime(2024, 1, 2),
      );
      final remote = painting(
        id: local.id,
        imageUrls: const [],
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(PaintingRepository.shouldAdoptRemote(local, remote), isFalse);
    });

    test('shouldAdoptRemote adopts newer remote even without URL difference',
        () {
      final local = painting(
        imageUrls: const ['https://cdn/x.jpg'],
        updatedAt: DateTime(2024, 1, 1),
      );
      final remote = painting(
        id: local.id,
        imageUrls: const ['https://cdn/x.jpg'],
        title: 'Edited on another device',
        updatedAt: DateTime(2024, 1, 3),
      );
      expect(PaintingRepository.shouldAdoptRemote(local, remote), isTrue);
    });

    test('shouldAdoptRemote always adopts when there is no local copy', () {
      final remote = painting();
      expect(PaintingRepository.shouldAdoptRemote(null, remote), isTrue);
    });

    test('local-only URLs are never wiped by a URL-less pull', () {
      final local = painting(
        imageUrls: const ['https://cdn/keep.jpg'],
        coverImageUrl: 'https://cdn/keep.jpg',
        updatedAt: DateTime(2024, 1, 2),
      );
      final remote = painting(
        id: local.id,
        imageUrls: const [],
        coverImageUrl: '',
        updatedAt: DateTime(2024, 1, 2),
      );
      expect(PaintingRepository.shouldAdoptRemote(local, remote), isFalse);
    });
  });

  group('profile edits survive re-login', () {
    test('updateProfile persists name + avatar locally when cloud is down',
        () async {
      await AuthRepository.instance.updateProfile(
        displayName: 'Kais Havery',
        photoPath: '/local/avatar.jpg',
        photoUrl: 'https://cdn/avatar.jpg',
      );

      final user = AuthRepository.instance.cachedUser;
      expect(user.displayName, 'Kais Havery');
      expect(user.photoPath, '/local/avatar.jpg');
      expect(user.photoUrl, 'https://cdn/avatar.jpg');
    });

    test('restoreSession keeps the locally edited profile (no cloud)',
        () async {
      // Seed a signed-in user, then simulate the user's edits landing in the
      // box (the cloud write failed or was offline).
      await LocalDatabase.instance.put(
        AppConstants.boxProfile,
        'me',
        AppUser(
          uid: 'uid-123',
          email: 'k@example.com',
          displayName: 'ArtVault User',
          createdAt: DateTime(2024, 1, 1),
          lastLogin: DateTime(2024, 1, 1),
        ).toJson(),
      );
      await AuthRepository.instance.updateProfile(
        displayName: 'Kais Havery',
        photoUrl: 'https://cdn/avatar.jpg',
      );
      await LocalDatabase.instance.setSetting(
        AppConstants.kSessionUid,
        'uid-123',
      );

      // A re-login with Firebase unavailable must NOT discard the edits:
      // the cached profile is returned as-is.
      final restored = await AuthRepository.instance.restoreSession();
      expect(restored.uid, 'uid-123');
      expect(restored.displayName, 'Kais Havery');
      expect(restored.photoUrl, 'https://cdn/avatar.jpg');
    });

    test('restoreSession with a fresh device starts from the placeholder',
        () async {
      // Box was never populated — no saved session.
      expect(
        () => AuthRepository.instance.restoreSession(),
        throwsA(isA<Exception>()),
      );
    });

    test('AppUser round-trips photoUrl through the box', () {
      final user = AppUser(
        uid: 'u1',
        email: 'k@example.com',
        displayName: 'Kais Havery',
        photoPath: '/local/avatar.jpg',
        photoUrl: 'https://cdn/avatar.jpg',
        bio: 'Collector',
        createdAt: DateTime(2024, 1, 1),
        lastLogin: DateTime(2024, 1, 1),
      );
      final restored = AppUser.fromJson(user.toJson());
      expect(restored.uid, 'u1');
      expect(restored.displayName, 'Kais Havery');
      expect(restored.photoUrl, 'https://cdn/avatar.jpg');
      expect(restored.bio, 'Collector');
    });
  });
}
