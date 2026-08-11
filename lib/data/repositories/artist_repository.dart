import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../local/local_database.dart';
import '../models/artist.dart';
import '../remote/cloud_backend.dart';

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

  Future<Artist> save(Artist artist, {File? photoFile}) async {
    var working = artist;
    if (photoFile != null) {
      final path = await FileStorageService.instance.importImage(photoFile);
      working = working.copyWith(photoPath: path, needsSync: true);
    }
    await _db.put(AppConstants.boxArtists, working.id, working.toJson());
    if (working.needsSync) unawaited(_syncArtist(working));
    BackupService.instance.scheduleAutoBackup();
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
  }

  Future<void> syncNow() async {
    if (!CloudBackend.instance.isReady) return;
    final dirty = readAll().where((a) => a.needsSync).toList();
    for (final artist in dirty) {
      await _syncArtist(artist);
    }
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
