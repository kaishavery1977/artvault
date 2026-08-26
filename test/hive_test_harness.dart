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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// A persistent secure-storage mock: writes are kept in memory so the
/// stored values survive across calls within a test.
final Map<String, String> _secureStore = <String, String>{};

void _stubSecureStoragePersist() {
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') {
      return _secureStore[call.arguments['key'] as String];
    }
    if (call.method == 'write') {
      _secureStore[call.arguments['key'] as String] =
          call.arguments['value'] as String;
      return null;
    }
    if (call.method == 'delete') {
      _secureStore.remove(call.arguments['key'] as String);
      return null;
    }
    if (call.method == 'deleteAll') {
      _secureStore.clear();
      return null;
    }
    if (call.method == 'readAll') {
      return Map<String, String>.from(_secureStore);
    }
    return null;
  });
}

/// Idempotent — call once per test file (e.g. in `setUpAll`).
/// Secure storage mock MUST be registered before LocalDatabase.init()
/// because Hive uses FlutterSecureStorage for the encryption key.
Future<void> initTestHive() async {
  // Ensure the test binding is initialized so
  // TestDefaultBinaryMessengerBinding.instance is available.
  TestWidgetsFlutterBinding.ensureInitialized();
  _stubSecureStoragePersist();
  if (!LocalDatabase.instance.isInitialized) {
    final dir = await Directory.systemTemp.createTemp('artvault_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    await LocalDatabase.instance.init();
  }
}

/// Wipes the settings box so a test starts from known defaults.
Future<void> clearTestSettings() async {
  await LocalDatabase.instance.box(AppConstants.boxSettings).clear();
}

/// Wipes the vault boxes (paintings, sync queue, …) so a test starts from
/// an empty vault.
Future<void> clearTestVault() async {
  final db = LocalDatabase.instance;
  await db.clear(AppConstants.boxPaintings);
  await db.clear(AppConstants.boxSyncQueue);
}
