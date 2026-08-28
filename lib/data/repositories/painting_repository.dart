import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/app_logger.dart';
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

  List<Painting> readActive() => readAll().where((p) => !p.isDeleted).toList();

  /// Paintings currently in the trash (soft-deleted, restorable).
  List<Painting> readTrash() => readAll().where((p) => p.isDeleted).toList();

  int countTrash() => readTrash().length;

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
      for (final file in newImageFiles.take(
        AppConstants.maxImagesPerPainting,
      )) {
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
    // Soft-delete: the record (and its photos) move to Trash so the painting
    // can be restored. Nothing is permanently removed until purge().
    await _db.put(
      AppConstants.boxPaintings,
      id,
      painting.copyWith(isDeleted: true, needsSync: true).toJson(),
    );
    unawaited(
      _syncPainting(painting.copyWith(isDeleted: true, needsSync: true)),
    );
    await NotificationService.instance.notify(
      'Painting moved to trash',
      '${painting.title} can be restored anytime.',
      type: 'system',
    );
    BackupService.instance.scheduleAutoBackup();
  }

  /// Permanently removes a painting — record, local photos and cloud copy.
  /// This cannot be undone.
  Future<void> purge(String id) async {
    final painting = get(id);
    if (painting == null) return;
    // Remove local photo files, then the record.
    final storage = FileStorageService.instance;
    for (final image in painting.images) {
      await storage.deleteFile(image);
    }
    await _db.delete(AppConstants.boxPaintings, id);
    // Tombstone the id (fire-and-forget cloud delete) so an offline purge
    // can't be re-created by the next pull. Removed once the cloud delete
    // is confirmed (see _removeRemote / _retryPurgedRemovals).
    await _db.put(AppConstants.boxSyncQueue, id, {
      'id': id,
      'purgedAt': DateTime.now().toIso8601String(),
    });
    unawaited(_removeRemote(painting));
    await NotificationService.instance.notify(
      'Painting deleted',
      '${painting.title} was permanently removed.',
      type: 'system',
    );
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> restore(String id) async {
    final painting = get(id);
    if (painting == null) return;
    final restored = painting.copyWith(isDeleted: false, needsSync: true);
    await _db.put(AppConstants.boxPaintings, id, restored.toJson());
    unawaited(_syncPainting(restored));
    BackupService.instance.scheduleAutoBackup();
  }

  /// Removes the cloud copy without touching the local record (used by purge).
  /// On success, clears any purge tombstone; on failure (offline) the
  /// tombstone persists so a later pull can't resurrect the purged item.
  Future<void> _removeRemote(Painting painting) async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady || cloud.currentUid.isEmpty) return;
    try {
      await cloud.remove(_collection, painting.id);
      await _db.delete(AppConstants.boxSyncQueue, painting.id);
    } catch (_) {
      // Network failure — keep tombstone, retried on the next sync.
    }
  }

  Future<void> toggleFavorite(String id) async {
    final painting = get(id);
    if (painting == null) return;
    final toggled = painting.copyWith(
      isFavorite: !painting.isFavorite,
      needsSync: true,
    );
    await _db.put(AppConstants.boxPaintings, id, toggled.toJson());
    unawaited(_syncPainting(toggled));
    BackupService.instance.scheduleAutoBackup();
  }

  // ------------------------------------------------------------ AI checks --

  /// Runs AI duplicate detection for a new artwork.
  Future<List<DuplicateMatch>> detectDuplicates(Painting painting) async {
    final others = readActive().where((p) => p.id != painting.id).toList();
    return AiService.instance.findDuplicates(painting, others);
  }

  /// Ranks the active collection by visual similarity to [painting]
  /// (best first) — drives the detail screen's "Similar paintings" rail.
  List<DuplicateMatch> findSimilar(Painting painting) {
    return AiService.instance.findSimilar(painting, readActive());
  }

  // -------------------------------------------------------------- Syncing --

  /// Pushes every dirty painting to the cloud, then pulls remote changes.
  Future<int> syncNow() async {
    if (!CloudBackend.instance.isReady) {
      debugPrint('PaintingRepository.syncNow: cloud not ready');
      return 0;
    }
    debugPrint('PaintingRepository.syncNow: starting…');
    final dirty = readAll().where((p) => p.needsSync).toList();
    debugPrint('PaintingRepository.syncNow: ${dirty.length} dirty paintings');
    for (final painting in dirty) {
      await _syncPainting(painting);
    }
    // Catch paintings that have local images but no cloud URLs yet.
    // These were created before the sync system or had a failed upload.
    for (final painting in readAll()) {
      if (painting.isDeleted || painting.needsSync) continue;
      final hasLocal = painting.images.any((p) => File(p).existsSync());
      final hasUrls = painting.imageUrls.any((u) => u.isNotEmpty);
      if (hasLocal && !hasUrls) {
        debugPrint(
          'PaintingRepository.syncNow: uploading images for ${painting.title}',
        );
        await _syncPainting(painting.copyWith(needsSync: true));
      }
    }
    // Retry removals for paintings purged while offline (the tombstone
    // queue keeps them from being re-created by _pullRemote below).
    await _retryPurgedRemovals();
    await _pullRemote();
    return dirty.length;
  }

  /// Re-downloads painting images from Storage after a reinstall or cache
  /// wipe: the local files are gone, but the remote [Painting.imageUrls]
  /// survived in Firestore. Skips paintings whose local files are already
  /// present. Returns the number of paintings whose images were recovered.
  ///
  /// Downloaded files are stored in the vault and the painting's local paths
  /// are updated WITHOUT re-uploading (the remote copies already exist), so
  /// this is safe to run on every sign-in — it is idempotent.
  Future<int> recoverImages() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return 0;
    final storage = FileStorageService.instance;
    var recovered = 0;
    for (final painting in readAll()) {
      if (painting.isDeleted) continue;
      final urls = painting.imageUrls;
      if (urls.isEmpty && painting.coverImageUrl.isEmpty) continue;
      final allLocal =
          painting.images.isNotEmpty &&
          painting.images.every((p) => File(p).existsSync()) &&
          (painting.coverImagePath.isEmpty ||
              File(painting.coverImagePath).existsSync());
      if (allLocal) continue;

      // (expected local path, remote url) pairs aligned by index.
      final pairs = <(String, String)>[
        for (var i = 0; i < painting.images.length; i++)
          (painting.images[i], i < urls.length ? urls[i] : ''),
      ];
      // Older docs may only carry a cover — add it as its own pair when it
      // isn't already covered by images[0].
      if (painting.coverImagePath.isNotEmpty &&
          pairs.every((pair) => pair.$1 != painting.coverImagePath)) {
        pairs.add((painting.coverImagePath, painting.coverImageUrl));
      }

      final newPaths = <String>[];
      for (final (local, url) in pairs) {
        if (local.isNotEmpty && File(local).existsSync()) {
          newPaths.add(local);
          continue;
        }
        if (url.isEmpty) continue;
        final bytes = await cloud.downloadBytes(url);
        if (bytes == null) continue;
        final path = await storage.saveImageBytes(bytes);
        newPaths.add(path);
        await storage.makeThumbnail(path);
      }
      if (newPaths.isEmpty) continue;

      final updated = painting
          .copyWith(images: newPaths, coverImagePath: newPaths.first)
          .markSynced(); // remote copies already exist — never re-upload
      await _db.put(AppConstants.boxPaintings, updated.id, updated.toJson());
      recovered++;
    }
    return recovered;
  }

  /// Purged ids awaiting a confirmed cloud delete. Purge writes a tombstone
  /// here (fire-and-forget), so an offline purge can't be resurrected by the
  /// next pull. Cleared once the remote delete succeeds.
  Set<String> _tombstones() {
    final raw = _db.getAll(AppConstants.boxSyncQueue);
    return raw.map((e) => e['id'] as String?).whereType<String>().toSet();
  }

  Future<void> _retryPurgedRemovals() async {
    final cloud = CloudBackend.instance;
    for (final id in _tombstones()) {
      try {
        await cloud.remove(_collection, id);
        await _db.delete(AppConstants.boxSyncQueue, id);
      } catch (_) {
        // Still offline — keep the tombstone, retry next sync.
      }
    }
  }

  Future<void> _syncPainting(Painting painting) async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      // Skip empty paintings that have no title and no images — they
      // should never reach the cloud.
      if (painting.title.trim().isEmpty &&
          painting.images.isEmpty &&
          painting.imageUrls.isEmpty &&
          painting.coverImageUrl.isEmpty) {
        return;
      }
      var working = painting.copyWith(ownerUid: uid);

      // Soft-deleted: remove the remote copy and keep the local record in
      // Trash (isDeleted stays true so it can be restored). Handle this
      // BEFORE the image upload, since markSynced() must never resurrect a
      // trashed painting.
      if (working.isDeleted) {
        await cloud.remove(_collection, working.id);
        await _db.put(
          AppConstants.boxPaintings,
          working.id,
          working.copyWith(needsSync: false, synced: true).toJson(),
        );
        return;
      }

      // Ensure the remote doc exists (with ownership) before uploading files,
      // so the Storage rules can authorise uploads via the Firestore doc.
      await cloud.upsert(_collection, working.id, working.toJson());

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
        working = working
            .copyWith(
              imageUrls: urls,
              coverImageUrl: urls.isNotEmpty
                  ? urls.first
                  : working.coverImageUrl,
            )
            .markSynced();
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
      final tombstones = _tombstones();
      final remote = await cloud.fetchAll(_collection, owner: uid);
      debugPrint(
        'PaintingRepository._pullRemote: fetched ${remote.length} paintings from Firestore',
      );
      for (final data in remote) {
        final painting = Painting.fromJson(data);
        // Never resurrect a painting purged locally (offline purge).
        if (tombstones.contains(painting.id)) continue;
        final local = get(painting.id);
        if (local == null || painting.updatedAt.isAfter(local.updatedAt)) {
          await _db.put(
            AppConstants.boxPaintings,
            painting.id,
            painting.toJson(),
          );
        }
      }
    } catch (e) {
      AppLogger.error('PaintingRepository._pullRemote', error: e);
    }
  }

  /// Generates a fresh id for a new painting.
  static String newId() => const Uuid().v4();
}
