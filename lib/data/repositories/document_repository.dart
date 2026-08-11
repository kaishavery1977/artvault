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

  List<ArtDocument> forPainting(String paintingId) =>
      readAll().where((d) => d.paintingId == paintingId && !d.isDeleted).toList();

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
    final localPath = await FileStorageService.instance.importDocument(file, name);
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
    await FileStorageService.instance.deleteFile(doc.localPath);
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
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    return 'application/octet-stream';
  }
}
