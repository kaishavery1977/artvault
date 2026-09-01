import 'dart:async';
import 'dart:convert';
import 'package:artvault/utils/io_shim.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/local/local_database.dart';
import '../../data/remote/cloud_backend.dart';
import '../../data/repositories/settings_repository.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'file_storage_service.dart';
import 'notification_service.dart';

/// Full vault backup & restore.
///
///  - Local: a single portable JSON bundle stored in the app documents.
///  - Cloud: mirrored to Firestore when Firebase is configured.
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  // ------------------------------------------------------------- Local backup --

  /// The settings Hive box stores primitive values (bool/string/int) keyed
  /// by name — not JSON maps — so it is exported as a plain map instead of
  /// going through [LocalDatabase.getAll] (which would crash on a cast).
  Map<String, dynamic> _settingsBundle() => {
    for (final key in LocalDatabase.instance.box(AppConstants.boxSettings).keys)
      key: LocalDatabase.instance.getSetting(key),
  };

  Future<File> exportLocalBackup() async {
    final db = LocalDatabase.instance;
    final bundle = <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': AppConstants.appName,
      'paintings': db.getAll(AppConstants.boxPaintings),
      'artists': db.getAll(AppConstants.boxArtists),
      'documents': db.getAll(AppConstants.boxDocuments),
      'settings': _settingsBundle(),
    };
    final file = File(
      p.join(
        FileStorageService.instance.exportsDir.path,
        'artvault_backup_${Formatters.fileStamp(DateTime.now())}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bundle),
    );
    return file;
  }

  Future<void> restoreLocalBackup(File file) async {
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final db = LocalDatabase.instance;

    if (decoded['paintings'] is List) {
      await db.putAll(
        AppConstants.boxPaintings,
        (decoded['paintings'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (decoded['artists'] is List) {
      await db.putAll(
        AppConstants.boxArtists,
        (decoded['artists'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (decoded['documents'] is List) {
      await db.putAll(
        AppConstants.boxDocuments,
        (decoded['documents'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (decoded['settings'] is Map) {
      for (final entry
          in (decoded['settings'] as Map<String, dynamic>).entries) {
        await db.setSetting(entry.key, entry.value);
      }
    }
  }

  // -------------------------------------------------------------- Cloud backup --

  /// Pushes a snapshot to Firestore. Returns false when Firebase is absent.
  Future<bool> pushCloudBackup() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return false;

    final db = LocalDatabase.instance;
    final uid = cloud.currentUser?.uid;
    if (uid == null) return false;

    await cloud.upsert('backups', uid, {
      'updatedAt': DateTime.now().toIso8601String(),
      'paintings': db.getAll(AppConstants.boxPaintings),
      'artists': db.getAll(AppConstants.boxArtists),
      'documents': db.getAll(AppConstants.boxDocuments),
      'settings': _settingsBundle(),
    });
    return true;
  }

  /// Pulls the cloud snapshot and merges into the local vault.
  Future<bool> restoreCloudBackup() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) {
      debugPrint('BackupService.restoreCloudBackup: cloud not ready');
      return false;
    }
    final uid = cloud.currentUser?.uid;
    if (uid == null) {
      debugPrint('BackupService.restoreCloudBackup: no uid');
      return false;
    }

    // Backups are keyed by the owner's uid, so fetch exactly this user's doc.
    debugPrint('BackupService.restoreCloudBackup: fetching backups/$uid');
    final data = await cloud.fetchDoc('backups', uid);
    if (data == null) {
      debugPrint('BackupService.restoreCloudBackup: no backup doc found');
      return false;
    }

    final db = LocalDatabase.instance;
    final paintingCount = (data['paintings'] as List?)?.length ?? 0;
    final artistCount = (data['artists'] as List?)?.length ?? 0;
    final docCount = (data['documents'] as List?)?.length ?? 0;
    debugPrint(
      'BackupService.restoreCloudBackup: paintings=$paintingCount artists=$artistCount docs=$docCount',
    );
    if (data['paintings'] is List) {
      await db.putAll(
        AppConstants.boxPaintings,
        (data['paintings'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['artists'] is List) {
      await db.putAll(
        AppConstants.boxArtists,
        (data['artists'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['documents'] is List) {
      await db.putAll(
        AppConstants.boxDocuments,
        (data['documents'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['settings'] is Map) {
      for (final entry in (data['settings'] as Map<String, dynamic>).entries) {
        await db.setSetting(entry.key, entry.value);
      }
    }
    return true;
  }

  /// Run a full backup round-trip and fire the corresponding notification.
  /// Returns whether the cloud snapshot was pushed and the local file name.
  Future<({bool cloud, String localFile})> runBackup() async {
    final local = await exportLocalBackup();
    final cloud = await pushCloudBackup();
    await NotificationService.instance.notify(
      'Backup completed',
      cloud
          ? 'Vault backed up to cloud and local file.'
          : 'Local backup saved: ${local.path.split(p.separator).last}',
      type: 'backup',
    );
    return (cloud: cloud, localFile: local.path.split(p.separator).last);
  }

  // -------------------------------------------------------------- Auto-backup --

  Timer? _autoDebounce;

  /// Queues a cloud snapshot a few seconds after a vault change. Called by
  /// the repositories after any write; honours the "Auto cloud backup"
  /// setting and requires Firebase + a signed-in user. Debounced so a burst
  /// of changes (e.g. typing a title) results in a single upload.
  void scheduleAutoBackup() {
    if (!SettingsRepository.instance.autoBackup) return;
    final cloud = CloudBackend.instance;
    if (!cloud.isReady || cloud.currentUid.isEmpty) return;
    _autoDebounce?.cancel();
    _autoDebounce = Timer(const Duration(seconds: 4), () {
      pushCloudBackup().then((ok) {
        if (ok) {
          NotificationService.instance.notify(
            'Auto cloud backup',
            'Your vault was synced to the cloud.',
            type: 'backup',
          );
        }
      });
    });
  }
}
