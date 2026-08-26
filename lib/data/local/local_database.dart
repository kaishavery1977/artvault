import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';

/// Thin typed wrapper around Hive boxes with AES-256 encryption at rest.
///
/// The encryption key is a random 256-bit value generated on first launch and
/// stored in Flutter Secure Storage (OS-level keychain).  Subsequent launches
/// retrieve the same key so existing boxes stay decryptable.
///
/// Entities are stored as `Map<String, dynamic>` JSON so no codegen/build
/// step is required and the schema stays transparent and versionable.
class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _secureKey = 'hive_aes_encryption_key';

  final Map<String, Box<dynamic>> _boxes = {};
  final Set<String> _opened = {};
  HiveAesCipher? _cipher;

  bool get isInitialized => _opened.isNotEmpty;

  Future<void> init() async {
    await Hive.initFlutter();
    _cipher = await _getCipher();
    const names = [
      AppConstants.boxSettings,
      AppConstants.boxPaintings,
      AppConstants.boxArtists,
      AppConstants.boxDocuments,
      AppConstants.boxConditionReports,
      AppConstants.boxNotifications,
      AppConstants.boxSyncQueue,
      AppConstants.boxProfile,
    ];
    for (final name in names) {
      await _open(name);
    }
  }

  /// Retrieves the existing AES key from secure storage, or generates a new
  /// one and persists it.  The key is a raw 32-byte (256-bit) value stored
  /// as a base64 string.
  static Future<HiveAesCipher> _getCipher() async {
    const secure = FlutterSecureStorage();
    final existing = await secure.read(key: _secureKey);
    List<int> keyBytes;
    if (existing != null && existing.isNotEmpty) {
      keyBytes = base64Url.decode(existing);
    } else {
      keyBytes = Hive.generateSecureKey();
      await secure.write(key: _secureKey, value: base64Url.encode(keyBytes));
    }
    return HiveAesCipher(keyBytes);
  }

  Future<Box<dynamic>> _open(String name) async {
    if (_boxes.containsKey(name)) return _boxes[name]!;
    Box<dynamic> box;
    try {
      // Try opening with encryption (normal path for new & existing encrypted
      // installations).
      box = await Hive.openBox<dynamic>(name, encryptionCipher: _cipher);
    } on HiveError catch (_) {
      // The box was written without encryption before this version shipped.
      // We can't re-encrypt in place, so we clear the unencrypted data and
      // re-open with encryption.  Vault data is re-synced from Firestore on
      // next launch; settings are lightweight and easily re-configured.
      box = await Hive.openBox<dynamic>(name);
      await box.clear();
      await box.close();
      box = await Hive.openBox<dynamic>(name, encryptionCipher: _cipher);
      // ignore: avoid_print
      print(
        'LocalDatabase: cleared unencrypted box "$name" '
        'and reopened with AES encryption.',
      );
    }
    _boxes[name] = box;
    _opened.add(name);
    return box;
  }

  Box<dynamic> box(String name) {
    final b = _boxes[name];
    if (b == null) {
      throw StateError('LocalDatabase not initialized for box "$name"');
    }
    return b;
  }

  // ---- Generic CRUD -------------------------------------------------------

  List<Map<String, dynamic>> getAll(String boxName) =>
      box(boxName).values.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Map<String, dynamic>? getById(String boxName, String id) {
    final value = box(boxName).get(id);
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> put(String boxName, String id, Map<String, dynamic> value) =>
      box(boxName).put(id, value);

  Future<void> putAll(String boxName, List<Map<String, dynamic>> values) async {
    final b = box(boxName);
    await b.putAll({for (final v in values) v['id'] as String: v});
  }

  Future<void> delete(String boxName, String id) => box(boxName).delete(id);

  Future<void> clear(String boxName) => box(boxName).clear();

  Future<int> count(String boxName) async => box(boxName).length;

  /// Reactive stream for a box (fires on any put/delete).
  Stream<void> watch(String boxName) => box(boxName).watch();

  // ---- Settings helpers ---------------------------------------------------

  Future<void> setSetting(String key, dynamic value) =>
      box(AppConstants.boxSettings).put(key, value);

  dynamic getSetting(String key, [dynamic fallback]) {
    final v = box(AppConstants.boxSettings).get(key);
    return v ?? fallback;
  }

  String? getString(String key, [String? fallback]) =>
      box(AppConstants.boxSettings).get(key) as String? ?? fallback;

  bool getBool(String key, [bool fallback = false]) =>
      box(AppConstants.boxSettings).get(key) as bool? ?? fallback;

  int getInt(String key, [int fallback = 0]) =>
      box(AppConstants.boxSettings).get(key) as int? ?? fallback;

  /// Wipes all data — used for sign-out (local vault data is kept) or the
  /// destructive "reset vault" option.
  Future<void> wipeEverything() async {
    for (final name in [
      AppConstants.boxPaintings,
      AppConstants.boxArtists,
      AppConstants.boxDocuments,
      AppConstants.boxNotifications,
      AppConstants.boxSyncQueue,
    ]) {
      await box(name).clear();
    }
  }
}
