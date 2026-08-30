import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/services/notification_service.dart';
import '../local/local_database.dart';
import '../models/art_document.dart';
import '../remote/cloud_backend.dart';
import '../../core/providers/data_providers.dart';

class DocumentRepository {
  DocumentRepository._();

  static final DocumentRepository instance = DocumentRepository._();

  static const _collection = 'documents';

  LocalDatabase get _db => LocalDatabase.instance;

  Stream<List<ArtDocument>> watchDocuments() async* {
    yield readAll();
    yield* _db.watch(AppConstants.boxDocuments).map((_) => readAll());
  }

  List<ArtDocument> readAll() {
    final raw = _db.getAll(AppConstants.boxDocuments);
    final list = raw.map(ArtDocument.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<ArtDocument> forPainting(String paintingId) => readAll()
      .where((d) => d.paintingId == paintingId && !d.isDeleted)
      .toList();

  ArtDocument? get(String id) {
    final raw = _db.getById(AppConstants.boxDocuments, id);
    return raw == null ? null : ArtDocument.fromJson(raw);
  }

  Future<ArtDocument> add({
    required String paintingId,
    required String type,
    required String name,
    required File file,
  }) async {
    final localPath = await FileStorageService.instance.importDocument(
      file,
      name,
    );
    final size = await file.length();
    final doc = ArtDocument(
      id: const Uuid().v4(),
      paintingId: paintingId,
      type: type,
      name: name,
      localPath: localPath,
      mimeType: _mimeFor(name),
      sizeBytes: size,
      createdAt: DateTime.now(),
    );
    await _db.put(AppConstants.boxDocuments, doc.id, doc.toJson());
    unawaited(_syncDocument(doc));
    await NotificationService.instance.notify(
      'Document added',
      '$name was attached to the painting.',
      type: 'upload',
    );
    BackupService.instance.scheduleAutoBackup();
    logActivity(ActivityType.documentAdd, name, meta: {'documentId': doc.id});
    return doc;
  }

  Future<void> rename(String id, String newName) async {
    final doc = get(id);
    if (doc == null) return;
    await _db.put(
      AppConstants.boxDocuments,
      id,
      doc.copyWith(name: newName, needsSync: true).toJson(),
    );
    unawaited(_syncDocument(doc.copyWith(name: newName, needsSync: true)));
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> delete(String id) async {
    final doc = get(id);
    if (doc == null) return;
    await _db.put(
      AppConstants.boxDocuments,
      id,
      doc.copyWith(isDeleted: true, needsSync: true).toJson(),
    );
    unawaited(_syncDocument(doc.copyWith(isDeleted: true, needsSync: true)));
    BackupService.instance.scheduleAutoBackup();
  }

  /// Restores a soft-deleted document (undo delete).
  Future<void> restore(String id) async {
    final doc = get(id);
    if (doc == null || !doc.isDeleted) return;
    await _db.put(
      AppConstants.boxDocuments,
      id,
      doc.copyWith(isDeleted: false, needsSync: true).toJson(),
    );
    unawaited(_syncDocument(doc.copyWith(isDeleted: false, needsSync: true)));
    BackupService.instance.scheduleAutoBackup();
  }

  Future<File?> openFile(ArtDocument doc) =>
      FileStorageService.instance.fileForPath(doc.localPath);

  Future<void> syncNow() async {
    if (!CloudBackend.instance.isReady) return;
    final dirty = readAll().where((d) => d.needsSync).toList();
    for (final doc in dirty) {
      await _syncDocument(doc);
    }
  }

  /// Pulls every remote document for this owner into the local box — the
  /// metadata half of reinstall recovery (a wiped vault has no local rows,
  /// so [recoverDocuments] alone finds nothing to restore). Local
  /// soft-deleted records are never resurrected.
  Future<void> pullRemote() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      final remote = await cloud.fetchAll(_collection, owner: uid);
      for (final data in remote) {
        final doc = ArtDocument.fromJson(data);
        final local = get(doc.id);
        if (local != null && local.isDeleted) continue;
        if (local == null || doc.createdAt.isAfter(local.createdAt)) {
          await _db.put(
            AppConstants.boxDocuments,
            doc.id,
            doc.copyWith(needsSync: false, synced: true).toJson(),
          );
        }
      }
      // Catch docs that have a local file but no cloud URL.
      for (final doc in readAll()) {
        if (doc.isDeleted || doc.needsSync) continue;
        if (doc.localPath.isNotEmpty &&
            doc.remoteUrl.isEmpty &&
            File(doc.localPath).existsSync()) {
          await _syncDocument(doc.copyWith(needsSync: true));
        }
      }
    } catch (_) {}
  }

  /// Re-imports a user-picked replacement file for a document whose local
  /// copy was lost (e.g. after a reinstall wiped the vault). Marks the doc
  /// for re-sync so the new file reaches the cloud on the next connection.
  Future<void> restoreFile(String id, File file) async {
    final doc = get(id);
    if (doc == null) return;
    final localPath = await FileStorageService.instance.importDocument(
      file,
      doc.name,
    );
    await _db.put(
      AppConstants.boxDocuments,
      id,
      doc.copyWith(localPath: localPath, needsSync: true).toJson(),
    );
    unawaited(
      _syncDocument(doc.copyWith(localPath: localPath, needsSync: true)),
    );
    BackupService.instance.scheduleAutoBackup();
  }

  /// Re-downloads attached documents from Storage after a reinstall (local
  /// file gone, [ArtDocument.remoteUrl] survived in Firestore). Skips docs
  /// already on disk. Returns the number of documents restored.
  Future<int> recoverDocuments() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return 0;
    final storage = FileStorageService.instance;
    var recovered = 0;
    for (final doc in readAll()) {
      if (doc.isDeleted || doc.remoteUrl.isEmpty) continue;
      if (doc.localPath.isNotEmpty && File(doc.localPath).existsSync()) {
        continue;
      }
      final bytes = await cloud.downloadBytes(doc.remoteUrl);
      if (bytes == null) continue;
      final path = await storage.saveDocumentBytes(bytes, doc.name);
      await _db.put(
        AppConstants.boxDocuments,
        doc.id,
        doc.copyWith(localPath: path, needsSync: false, synced: true).toJson(),
      );
      recovered++;
    }
    return recovered;
  }

  Future<void> _syncDocument(ArtDocument doc) async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      var working = doc.copyWith(ownerUid: uid);

      // Ensure the remote doc exists (with ownership) before uploading, so
      // the Storage rules can authorise the upload via the Firestore doc.
      if (!working.isDeleted) {
        await cloud.upsert(_collection, working.id, working.toJson());
      }
      if (working.localPath.isNotEmpty && working.remoteUrl.isEmpty) {
        final file = File(working.localPath);
        if (await file.exists()) {
          final url = await cloud.uploadBytes(
            'documents/${working.id}/${working.name}',
            await file.readAsBytes(),
            contentType: working.mimeType,
          );
          if (url != null) working = working.copyWith(remoteUrl: url);
        }
      }
      if (working.isDeleted) {
        await cloud.remove(_collection, working.id);
        await _db.delete(AppConstants.boxDocuments, working.id);
        return;
      }
      final finalDoc = working.copyWith(needsSync: false, synced: true);
      await cloud.upsert(_collection, working.id, finalDoc.toJson());
      await _db.put(AppConstants.boxDocuments, working.id, finalDoc.toJson());
    } catch (_) {}
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    return 'application/octet-stream';
  }
}
