import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../local/local_database.dart';
import '../models/artist.dart';
import '../remote/cloud_backend.dart';
import '../../core/providers/data_providers.dart';

class ArtistRepository {
  ArtistRepository._();

  static final ArtistRepository instance = ArtistRepository._();

  static const _collection = 'artists';

  LocalDatabase get _db => LocalDatabase.instance;

  Stream<List<Artist>> watchArtists() async* {
    yield readAll();
    yield* _db.watch(AppConstants.boxArtists).map((_) => readAll());
  }

  List<Artist> readAll() {
    final raw = _db.getAll(AppConstants.boxArtists);
    final list = raw.map(Artist.fromJson).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<Artist> readActive() => readAll().where((a) => !a.isDeleted).toList();

  Artist? get(String id) {
    final raw = _db.getById(AppConstants.boxArtists, id);
    return raw == null ? null : Artist.fromJson(raw);
  }

  Artist? findByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final artist in readActive()) {
      if (artist.name.toLowerCase() == needle) return artist;
    }
    return null;
  }

  /// Returns true if an active artist with [name] exists, excluding [excludeId].
  bool existsByName(String name, {String? excludeId}) {
    final needle = name.trim().toLowerCase();
    for (final artist in readActive()) {
      if (artist.id == excludeId) continue;
      if (artist.name.toLowerCase() == needle) return true;
    }
    return false;
  }

  Future<Artist> save(Artist artist, {File? photoFile}) async {
    var working = artist;
    if (photoFile != null) {
      final path = await FileStorageService.instance.importImage(photoFile);
      working = working.copyWith(photoPath: path, needsSync: true);
    }
    await _db.put(AppConstants.boxArtists, working.id, working.toJson());
    if (working.needsSync) unawaited(_syncArtist(working));
    BackupService.instance.scheduleAutoBackup();
    logActivity(ActivityType.artistAdd, '${working.name}');
    return working;
  }

  Future<void> delete(String id) async {
    final artist = get(id);
    if (artist == null) return;
    await _db.put(
      AppConstants.boxArtists,
      id,
      artist.copyWith(isDeleted: true, needsSync: true).toJson(),
    );
    unawaited(_syncArtist(artist.copyWith(isDeleted: true, needsSync: true)));
    BackupService.instance.scheduleAutoBackup();
    logActivity(ActivityType.artistDelete, '${artist.name}');
  }

  /// Restores a soft-deleted artist (undo delete).
  Future<void> restore(String id) async {
    final artist = get(id);
    if (artist == null || !artist.isDeleted) return;
    await _db.put(
      AppConstants.boxArtists,
      id,
      artist.copyWith(isDeleted: false, needsSync: true).toJson(),
    );
    unawaited(_syncArtist(artist.copyWith(isDeleted: false, needsSync: true)));
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> syncNow() async {
    if (!CloudBackend.instance.isReady) return;
    final dirty = readAll().where((a) => a.needsSync).toList();
    for (final artist in dirty) {
      await _syncArtist(artist);
    }
  }

  /// Pulls every remote artist for this owner into the local box — the
  /// metadata half of reinstall recovery (a wiped vault has no local rows,
  /// so [recoverPhotos] alone finds nothing to restore). Local soft-deleted
  /// records are never resurrected: their delete is still pending a remote
  /// confirmation and would otherwise be re-created by the pull.
  Future<void> pullRemote() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      final remote = await cloud.fetchAll(_collection, owner: uid);
      for (final data in remote) {
        final artist = Artist.fromJson(data);
        final local = get(artist.id);
        if (local != null && local.isDeleted) continue;
        if (local == null || artist.updatedAt.isAfter(local.updatedAt)) {
          await _db.put(
            AppConstants.boxArtists,
            artist.id,
            artist.copyWith(needsSync: false, synced: true).toJson(),
          );
        }
      }
      // Catch artists that have a local photo but no cloud URL.
      for (final artist in readAll()) {
        if (artist.isDeleted || artist.needsSync) continue;
        if (artist.photoPath.isNotEmpty &&
            artist.photoUrl.isEmpty &&
            File(artist.photoPath).existsSync()) {
          await _syncArtist(artist.copyWith(needsSync: true));
        }
      }
    } catch (_) {}
  }

  /// Re-downloads artist photos from Storage after a reinstall (local file
  /// gone, [Artist.photoUrl] survived in Firestore). Skips artists whose
  /// photo is already on disk. Returns the number of photos restored.
  Future<int> recoverPhotos() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return 0;
    final storage = FileStorageService.instance;
    var recovered = 0;
    for (final artist in readAll()) {
      if (artist.isDeleted || artist.photoUrl.isEmpty) continue;
      if (artist.photoPath.isNotEmpty && File(artist.photoPath).existsSync()) {
        continue;
      }
      final bytes = await cloud.downloadBytes(artist.photoUrl);
      if (bytes == null) continue;
      final path = await storage.saveImageBytes(bytes);
      await storage.makeThumbnail(path);
      await _db.put(
        AppConstants.boxArtists,
        artist.id,
        artist
            .copyWith(photoPath: path, needsSync: false, synced: true)
            .toJson(),
      );
      recovered++;
    }
    return recovered;
  }

  Future<void> _syncArtist(Artist artist) async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      var working = artist.copyWith(ownerUid: uid);

      // Ensure the remote doc exists (with ownership) before uploading, so
      // the Storage rules can authorise the upload via the Firestore doc.
      if (!working.isDeleted) {
        await cloud.upsert(_collection, working.id, working.toJson());
      }
      if (working.photoPath.isNotEmpty && working.photoUrl.isEmpty) {
        final file = File(working.photoPath);
        if (await file.exists()) {
          final url = await cloud.uploadBytes(
            'artists/${working.id}/photo.jpg',
            await file.readAsBytes(),
          );
          if (url != null) working = working.copyWith(photoUrl: url);
        }
      }
      if (working.isDeleted) {
        await cloud.remove(_collection, working.id);
        await _db.delete(AppConstants.boxArtists, working.id);
        return;
      }
      final finalArtist = working.copyWith(needsSync: false, synced: true);
      await cloud.upsert(_collection, working.id, finalArtist.toJson());
      await _db.put(AppConstants.boxArtists, working.id, finalArtist.toJson());
    } catch (_) {}
  }

  static String newId() => const Uuid().v4();
}
