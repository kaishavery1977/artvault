import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return SettingsRepository.instance.themeMode;
});

final localeProvider = StateProvider<String>((ref) {
  return SettingsRepository.instance.locale;
});

/// True when the user has finished onboarding.
final onboardedProvider = StateProvider<bool>((ref) {
  return SettingsRepository.instance.onboarded;
});

/// True once the full cinematic splash intro has played; drives the switch
/// to the shorter quick intro on subsequent launches.
final splashIntroShownProvider = StateProvider<bool>((ref) {
  return SettingsRepository.instance.splashIntroShown;
});

/// Preferred currency used across the UI.
final currencyProvider = Provider<String>((ref) {
  return SettingsRepository.instance.preferredCurrency;
});

/// Emits whenever the settings box changes (celebration history, theme,
/// toggles) so widgets like the About Celebrations card rebuild live.
final settingsBoxProvider = StreamProvider<void>((ref) {
  return SettingsRepository.instance.watchSettings();
});
