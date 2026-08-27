import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../local/local_database.dart';

/// Persisted user preferences (theme, locale, security toggles, …).
class SettingsRepository {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  LocalDatabase get _db => LocalDatabase.instance;

  bool get onboarded => _db.getBool(AppConstants.kOnboarded);

  Future<void> setOnboarded() => _db.setSetting(AppConstants.kOnboarded, true);

  /// Whether the full cinematic splash intro has played at least once.
  bool get splashIntroShown => _db.getBool(AppConstants.kSplashIntroShown);

  Future<void> setSplashIntroShown() =>
      _db.setSetting(AppConstants.kSplashIntroShown, true);

  ThemeMode get themeMode {
    final v = _db.getString(AppConstants.kThemeMode, 'system');
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _db.setSetting(AppConstants.kThemeMode, mode.name);

  String get locale => _db.getString(AppConstants.kLocale, 'en') ?? 'en';

  Future<void> setLocale(String code) =>
      _db.setSetting(AppConstants.kLocale, code);

  bool get notificationsEnabled =>
      _db.getBool(AppConstants.kNotificationsEnabled, true);

  Future<void> setNotificationsEnabled(bool value) =>
      _db.setSetting(AppConstants.kNotificationsEnabled, value);

  bool get appLockEnabled => _db.getBool(AppConstants.kAppLockEnabled);

  Future<void> setAppLockEnabled(bool value) =>
      _db.setSetting(AppConstants.kAppLockEnabled, value);

  bool get autoBackup => _db.getBool(AppConstants.kAutoBackup, true);

  Future<void> setAutoBackup(bool value) =>
      _db.setSetting(AppConstants.kAutoBackup, value);

  String get preferredCurrency =>
      _db.getString(AppConstants.kCurrency, 'USD') ?? 'USD';

  Future<void> setPreferredCurrency(String code) =>
      _db.setSetting(AppConstants.kCurrency, code);

  String get libraryLocation =>
      _db.getString(AppConstants.kLibraryLocation, 'Private Collection') ??
      'Private Collection';

  Future<void> setLibraryLocation(String value) =>
      _db.setSetting(AppConstants.kLibraryLocation, value);

  /// Celebration history: newest first, each entry a `{id, at}` record with
  /// `at` in epoch milliseconds. Kept in a JSON string inside the settings
  /// box so the About screen can show when each moment fired.
  List<Map<String, dynamic>> get celebrationHistory {
    final raw = _db.getString(AppConstants.kCelebrationHistory);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // Newest first. Timestamps are stored with microsecond precision, so
      // ordering is deterministic even for celebrations fired in quick
      // succession (a later mark always sorts ahead of an earlier one).
      list.sort((a, b) {
        final atA = (a['at'] as num?)?.toInt() ?? 0;
        final atB = (b['at'] as num?)?.toInt() ?? 0;
        return atB.compareTo(atA);
      });
      return List.unmodifiable(list);
    } catch (_) {
      return const [];
    }
  }

  /// Whether [id] has been celebrated recently (within the cooldown). The
  /// same celebration (e.g. the Pro unlock) is shown once, so relaunching or
  /// re-tapping the same moment doesn't replay the confetti every time.
  bool wasCelebratedRecently(
    String id, {
    Duration within = const Duration(hours: 24),
  }) {
    for (final entry in celebrationHistory) {
      if (entry['id'] != id) continue;
      final at = (entry['at'] as num?)?.toInt() ?? 0;
      if (at == 0) return false;
      return DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(at),
          ) <
          within;
    }
    return false;
  }

  Future<void> markCelebrated(String id) async {
    // Copy to a mutable list: one entry per celebration id, newest first.
    final history = List<Map<String, dynamic>>.from(celebrationHistory)
      ..removeWhere((e) => e['id'] == id);
    history.insert(
      0,
      // Microsecond precision so rapid successive celebrations keep a
      // deterministic newest-first order (see celebrationHistory).
      {'id': id, 'at': DateTime.now().microsecondsSinceEpoch},
    );
    // Cap the list so it can't grow forever.
    final trimmed = history.take(20).toList();
    await _db.setSetting(AppConstants.kCelebrationHistory, jsonEncode(trimmed));
  }

  /// Role hint used to seed brand-new users. Managed through AuthRepository.
  Stream<void> watchSettings() => _db.watch(AppConstants.boxSettings);
}
