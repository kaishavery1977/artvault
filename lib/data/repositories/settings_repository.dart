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

  Future<void> setLocale(String code) => _db.setSetting(AppConstants.kLocale, code);

  bool get notificationsEnabled => _db.getBool(AppConstants.kNotificationsEnabled, true);

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

  /// Whether [id] has been celebrated recently (within the cooldown). The
  /// same celebration (e.g. the Pro unlock) is shown once, so relaunching or
  /// re-tapping the same moment doesn't replay the confetti every time.
  bool wasCelebratedRecently(String id, {Duration within = const Duration(hours: 24)}) {
    final stored = _db.getString(AppConstants.kLastCelebrationId);
    final at = _db.getInt(AppConstants.kLastCelebrationAt);
    // `getInt` defaults to 0 when unset — treat that as never celebrated.
    if (stored != id || at == 0) return false;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(at),
        ) <
        within;
  }

  Future<void> markCelebrated(String id) async {
    await _db.setSetting(AppConstants.kLastCelebrationId, id);
    await _db.setSetting(
      AppConstants.kLastCelebrationAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Role hint used to seed brand-new users. Managed through AuthRepository.
  Stream<void> watchSettings() => _db.watch(AppConstants.boxSettings);
}
