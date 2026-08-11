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

  /// Role hint used to seed brand-new users. Managed through AuthRepository.
  Stream<void> watchSettings() => _db.watch(AppConstants.boxSettings);
}
