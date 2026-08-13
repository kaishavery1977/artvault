// Test harness that makes LocalDatabase (Hive) usable inside widget tests.
//
// LocalDatabase.init() calls Hive.initFlutter(), which resolves the app
// documents directory through path_provider — unavailable in tests. We swap
// in a fake PathProviderPlatform that points at a fresh temp directory, so
// Hive initializes for real and settings/profile boxes work like on device.
//
// Note: Hive caches open boxes globally and LocalDatabase is a singleton, so
// initialization is one-time per test process; individual tests clear the
// boxes they depend on via [clearTestSettings].

import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Initializes Hive-backed storage against a fresh temp directory.
/// Idempotent — call once per test file (e.g. in `setUpAll`).
Future<void> initTestHive() async {
  if (LocalDatabase.instance.isInitialized) return;
  final dir = await Directory.systemTemp.createTemp('artvault_test');
  PathProviderPlatform.instance = _FakePathProvider(dir.path);
  await LocalDatabase.instance.init();
}

/// Wipes the settings box so a test starts from known defaults.
Future<void> clearTestSettings() async {
  await LocalDatabase.instance.box(AppConstants.boxSettings).clear();
}
