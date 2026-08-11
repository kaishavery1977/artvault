import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/services/notification_service.dart';
import '../local/local_database.dart';
import '../models/painting.dart';
import '../remote/cloud_backend.dart';

/// Offline-first repository for paintings.
///
/// The Hive box is the source of truth; Cloud Firestore + Storage are the
/// remote mirror. Writes land locally first (instant UX) and are synced in
/// the background. Reads are always local → instant + works offline.
class PaintingRepository {
  PaintingRepository._();

  static final PaintingRepository instance = PaintingRepository._();

  static const _collection = 'paintings';

  LocalDatabase get _db => LocalDatabase.instance;

  // --------------------------------------------------------------- Reads --

  Stream<List<Painting>> watchPaintings() async* {
    yield readAll();
    yield* _db.watch(AppConstants.boxPaintings).map((_) => readAll());
  }

  List<Painting> readAll() {
    final raw = _db.getAll(AppConstants.boxPaintings);
    final list = raw.map(Painting.fromJson).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<Painting> readActive() =>
      readAll().where((p) => !p.isDeleted).toList();

  Painting? get(String id) {
    final raw = _db.getById(AppConstants.boxPaintings, id);
    return raw == null ? null : Painting.fromJson(raw);
  }

  int countActive() => readActive().length;

  // -------------------------------------------------------------- Writes --

  /// Creates or updates a painting. [newImagePaths] are imported into the
  /// vault and become the painting's gallery. Returns the saved painting.
  Future<Painting> save(
    Painting painting, {
    List<File>? newImageFiles,
    List<String>? replaceImages,
  }) async {
    var working = painting;
    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      final storage = FileStorageService.instance;
      final imported = <String>[];
      final thumbs = <String>[];
      for (final file in newImageFiles.take(AppConstants.maxImagesPerPainting)) {
        final path = await storage.importImage(file);
        imported.add(path);
        final thumb = await storage.makeThumbnail(path);
        if (thumb != path) thumbs.add(thumb);
      }

      final baseImages = replaceImages ?? [...working.images];
      final images = [...baseImages, ...imported];
      working = working.copyWith(
        images: images,
        coverImagePath: working.coverImagePath.isNotEmpty
            ? working.coverImagePath
            : (images.isNotEmpty ? images.first : ''),
        needsSync: true,
        updatedAt: DateTime.now(),
      );
    }

    // Ensure the AI hash exists (duplicate detection) — compute if missing.
    if (working.aiHash.isEmpty && working.coverImagePath.isNotEmpty) {
      final file = File(working.coverImagePath);
      if (await file.exists()) {
        working = working.copyWith(
          aiHash: await AiService.instance.hashOfFile(file),
        );
      }
    }

    await _db.put(AppConstants.boxPaintings, working.id, working.toJson());

    // Background sync (upload images + write to Firestore) — never blocks UI.
    if (working.needsSync) {
      unawaited(_syncPainting(working));
    }
    BackupService.instance.scheduleAutoBackup();
    return working;
  }

  Future<void> delete(String id) async {
    final painting = get(id);
    if (painting == null) return;
    // Soft-delete locally so background sync can remove the remote copy too.
    await _db.put(
      AppConstants.boxPaintings,
      id,
      painting.copyWith(isDeleted: true, needsSync: true).toJson(),
    );
    unawaited(_syncPainting(painting.copyWith(isDeleted: true, needsSync: true)));
    // Clean up local files.
    final storage = FileStorageService.instance;
    for (final image in painting.images) {
      await storage.deleteFile(image);
    }
    await NotificationService.instance.notify(
      'Painting removed',
      '${painting.title} was deleted from your vault.',
      type: 'system',
    );
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> restore(String id) async {
    final painting = get(id);
    if (painting == null) return;
    await _db.put(
      AppConstants.boxPaintings,
      id,
      painting.copyWith(isDeleted: false, needsSync: true).toJson(),
    );
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> toggleFavorite(String id) async {
    final painting = get(id);
    if (painting == null) return;
    await _db.put(
      AppConstants.boxPaintings,
      id,
      painting.copyWith(isFavorite: !painting.isFavorite, needsSync: true).toJson(),
    );
    BackupService.instance.scheduleAutoBackup();
  }

  // ------------------------------------------------------------ AI checks --

  /// Runs AI duplicate detection for a new artwork.
  Future<List<DuplicateMatch>> detectDuplicates(Painting painting) async {
    final others = readActive().where((p) => p.id != painting.id).toList();
    return AiService.instance.findDuplicates(painting, others);
  }

  // -------------------------------------------------------------- Syncing --

  /// Pushes every dirty painting to the cloud, then pulls remote changes.
  Future<int> syncNow() async {
    if (!CloudBackend.instance.isReady) return 0;
    final dirty = readAll().where((p) => p.needsSync).toList();
    for (final painting in dirty) {
      await _syncPainting(painting);
    }
    await _pullRemote();
    return dirty.length;
  }

  Future<void> _syncPainting(Painting painting) async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      var working = painting.copyWith(ownerUid: uid);

      // Ensure the remote doc exists (with ownership) before uploading files,
      // so the Storage rules can authorise uploads via the Firestore doc.
      if (!working.isDeleted) {
        await cloud.upsert(_collection, working.id, working.toJson());
      }

      // Upload any local images not yet mirrored.
      final urls = [...working.imageUrls];
      for (var i = 0; i < working.images.length; i++) {
        final local = working.images[i];
        if (i < urls.length && urls[i].isNotEmpty) continue;
        final file = File(local);
        if (!await file.exists()) continue;
        final name = local.split(Platform.pathSeparator).last;
        final url = await cloud.uploadBytes(
          'paintings/${working.id}/$name',
          await file.readAsBytes(),
          contentType: 'image/jpeg',
        );
        if (url != null) urls.add(url);
      }
      if (urls.length < working.images.length) {
        // Missing remote mirrors for some images — keep dirty.
        working = working.copyWith(imageUrls: urls, needsSync: true);
      } else {
        working = working.copyWith(
          imageUrls: urls,
          coverImageUrl: urls.isNotEmpty ? urls.first : working.coverImageUrl,
        ).markSynced();
      }
      if (working.isDeleted) {
        await cloud.remove(_collection, working.id);
        await _db.delete(AppConstants.boxPaintings, working.id);
        return;
      }
      await cloud.upsert(_collection, working.id, working.toJson());
      await _db.put(AppConstants.boxPaintings, working.id, working.toJson());
    } catch (_) {
      // Network failure — leave dirty, retried on next sync.
    }
  }

  Future<void> _pullRemote() async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      final remote = await cloud.fetchAll(_collection, owner: uid);
      for (final data in remote) {
        final painting = Painting.fromJson(data);
        final local = get(painting.id);
        if (local == null || painting.updatedAt.isAfter(local.updatedAt)) {
          await _db.put(AppConstants.boxPaintings, painting.id, painting.toJson());
        }
      }
    } catch (_) {}
  }

  /// Generates a fresh id for a new painting.
  static String newId() => const Uuid().v4();
}
