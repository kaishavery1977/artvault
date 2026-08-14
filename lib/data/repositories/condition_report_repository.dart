import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../local/local_database.dart';
import '../models/condition_report.dart';
import '../remote/cloud_backend.dart';

/// Persists [ConditionReport]s locally (Hive) and mirrors them to Firestore
/// + Storage so condition history survives re-installs and shows on other
/// devices — the same ownership-first sync pattern as documents.
class ConditionReportRepository {
  ConditionReportRepository._();

  static final ConditionReportRepository instance =
      ConditionReportRepository._();

  static const _collection = 'condition_reports';

  LocalDatabase get _db => LocalDatabase.instance;

  Stream<List<ConditionReport>> watchReports() async* {
    yield readAll();
    yield* _db.watch(AppConstants.boxConditionReports).map((_) => readAll());
  }

  List<ConditionReport> readAll() {
    final raw = _db.getAll(AppConstants.boxConditionReports);
    final list = raw.map(ConditionReport.fromJson).toList();
    list.sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    return list;
  }

  List<ConditionReport> forPainting(String paintingId) => readAll()
      .where((r) => r.paintingId == paintingId && !r.isDeleted)
      .toList();

  ConditionReport? latestFor(String paintingId) {
    final reports = forPainting(paintingId);
    if (reports.isEmpty) return null;
    reports.sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    return reports.first;
  }

  ConditionReport? get(String id) {
    final raw = _db.getById(AppConstants.boxConditionReports, id);
    return raw == null ? null : ConditionReport.fromJson(raw);
  }

  Future<ConditionReport> add({
    required String paintingId,
    required String condition,
    required String notes,
    required DateTime inspectedAt,
    File? photo,
  }) async {
    var photoPath = '';
    if (photo != null) {
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_condition_'
          '${photo.uri.pathSegments.isNotEmpty ? photo.uri.pathSegments.last : 'photo.jpg'}';
      photoPath = await FileStorageService.instance.importDocument(photo, name);
    }
    final report = ConditionReport(
      id: const Uuid().v4(),
      paintingId: paintingId,
      condition: condition,
      notes: notes,
      photoPath: photoPath,
      inspectedAt: inspectedAt,
      createdAt: DateTime.now(),
    );
    await _db.put(
      AppConstants.boxConditionReports,
      report.id,
      report.toJson(),
    );
    unawaited(_syncReport(report));
    BackupService.instance.scheduleAutoBackup();
    return report;
  }

  Future<void> delete(String id) async {
    final report = get(id);
    if (report == null) return;
    await _db.put(
      AppConstants.boxConditionReports,
      id,
      report.copyWith(isDeleted: true, needsSync: true).toJson(),
    );
    unawaited(_syncReport(report.copyWith(isDeleted: true, needsSync: true)));
    if (report.photoPath.isNotEmpty) {
      await FileStorageService.instance.deleteFile(report.photoPath);
    }
    BackupService.instance.scheduleAutoBackup();
  }

  Future<void> syncNow() async {
    if (!CloudBackend.instance.isReady) return;
    final dirty =
        readAll().where((r) => r.needsSync).toList();
    for (final report in dirty) {
      await _syncReport(report);
    }
  }

  Future<void> _syncReport(ConditionReport report) async {
    final cloud = CloudBackend.instance;
    try {
      final uid = cloud.currentUid;
      if (uid.isEmpty) return;
      var working = report.copyWith(ownerUid: uid);

      if (!working.isDeleted) {
        await cloud.upsert(_collection, working.id, working.toJson());
      }
      if (working.photoPath.isNotEmpty && working.photoUrl.isEmpty) {
        final file = File(working.photoPath);
        if (await file.exists()) {
          final url = await cloud.uploadBytes(
            'condition_reports/${working.id}/photo.jpg',
            await file.readAsBytes(),
            contentType: 'image/jpeg',
          );
          if (url != null) working = working.copyWith(photoUrl: url);
        }
      }
      if (working.isDeleted) {
        await cloud.remove(_collection, working.id);
        await _db.delete(AppConstants.boxConditionReports, working.id);
        return;
      }
      final finalReport =
          working.copyWith(needsSync: false, synced: true);
      await cloud.upsert(_collection, working.id, finalReport.toJson());
      await _db.put(
        AppConstants.boxConditionReports,
        working.id,
        finalReport.toJson(),
      );
    } catch (_) {}
  }
}
