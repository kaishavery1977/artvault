// Unit tests for GoogleDriveService: auth state, safe no-ops, and
// model integration. Since GoogleDriveService makes HTTP calls to the
// Drive REST API, these tests verify the service's internal logic without
// making actual network requests.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/google_drive_service.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/data/models/art_document.dart';

void main() {
  group('GoogleDriveService auth state', () {
    test('isReady is false when not authenticated', () {
      final service = GoogleDriveService.instance;
      service.signOut();
      expect(service.isReady, isFalse);
    });

    test('signOut clears credentials', () {
      final service = GoogleDriveService.instance;
      service.signOut();
      expect(service.isReady, isFalse);
    });

    test('singleton returns the same instance', () {
      expect(GoogleDriveService.instance, same(GoogleDriveService.instance));
    });
  });

  group('GoogleDriveService safe no-ops when unauthenticated', () {
    late GoogleDriveService service;

    setUp(() {
      service = GoogleDriveService.instance;
      service.signOut();
    });

    test('uploadBytes returns null', () async {
      final result = await service.uploadBytes(
        drivePath: 'paintings/test-id/cover.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(result, isNull);
    });

    test('downloadBytes returns null', () async {
      final result = await service.downloadBytes('fake-file-id');
      expect(result, isNull);
    });

    test('downloadByPath returns null', () async {
      final result = await service.downloadByPath(
        'paintings/test-id/cover.jpg',
      );
      expect(result, isNull);
    });

    test('deleteFile does not throw', () async {
      await service.deleteFile('fake-file-id');
    });

    test('deleteByPath does not throw', () async {
      await service.deleteByPath('paintings/test-id/cover.jpg');
    });

    test('deleteFolder does not throw', () async {
      await service.deleteFolder('fake-folder-id');
    });
  });

  group('Painting model driveFileIds', () {
    test('round-trips through JSON with driveFileIds', () {
      final painting = Painting(
        id: 'test-1',
        title: 'Test Painting',
        artistId: 'a1',
        artistName: 'Artist',
        driveFileIds: ['file-1', 'file-2'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final json = painting.toJson();
      expect(json['driveFileIds'], ['file-1', 'file-2']);

      final restored = Painting.fromJson(json);
      expect(restored.driveFileIds, ['file-1', 'file-2']);
    });

    test('fromJson handles missing driveFileIds (backward compat)', () {
      final json = {
        'id': 'test-1',
        'title': 'Test',
        'artistId': '',
        'artistName': '',
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      };

      final painting = Painting.fromJson(json);
      expect(painting.driveFileIds, isEmpty);
    });

    test('copyWith updates driveFileIds', () {
      final painting = Painting(
        id: 'test-1',
        title: 'Test',
        artistId: '',
        artistName: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final updated = painting.copyWith(driveFileIds: ['new-id']);
      expect(updated.driveFileIds, ['new-id']);
      expect(painting.driveFileIds, isEmpty); // original unchanged
    });
  });

  group('ArtDocument model driveFileId', () {
    test('round-trips through JSON with driveFileId', () {
      final doc = ArtDocument(
        id: 'doc-1',
        paintingId: 'p1',
        type: 'Certificate',
        name: 'cert.pdf',
        driveFileId: 'drive-file-123',
        createdAt: DateTime(2026),
      );

      final json = doc.toJson();
      expect(json['driveFileId'], 'drive-file-123');

      final restored = ArtDocument.fromJson(json);
      expect(restored.driveFileId, 'drive-file-123');
    });

    test('fromJson handles missing driveFileId (backward compat)', () {
      final json = {
        'id': 'doc-1',
        'paintingId': 'p1',
        'type': 'Other',
        'name': 'file.pdf',
        'createdAt': DateTime(2026).toIso8601String(),
      };

      final doc = ArtDocument.fromJson(json);
      expect(doc.driveFileId, isEmpty);
    });

    test('copyWith updates driveFileId', () {
      final doc = ArtDocument(
        id: 'doc-1',
        paintingId: 'p1',
        type: 'Other',
        name: 'file.pdf',
        createdAt: DateTime(2026),
      );

      final updated = doc.copyWith(driveFileId: 'new-drive-id');
      expect(updated.driveFileId, 'new-drive-id');
      expect(doc.driveFileId, isEmpty); // original unchanged
    });
  });
}
