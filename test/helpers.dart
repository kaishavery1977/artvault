// Shared helpers for widget tests: provider overrides that keep storage and
// Firebase out of the picture, plus pump helpers for the boot sequence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:artvault/core/providers/providers.dart';

/// Stops google_fonts from fetching fonts over HTTP in tests (the test
/// HttpClient returns 400 for every request); it falls back to the default
/// font family instead. Call from each test file's `setUpAll`.
void disableRuntimeFontFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Auth controller whose [bootstrap] never touches local/secure storage.
///
/// An optional initial [state] can be passed for tests that pump a screen
/// directly (nothing calls `bootstrap()` then, so a curated auth state must
/// come in through the constructor).
class FakeAuthController extends AuthController {
  FakeAuthController([AuthState? initial]) {
    if (initial != null) state = initial;
  }

  @override
  Future<void> bootstrap() async {
    // Defer past the build phase — modifying a provider inside initState is
    // not allowed by Riverpod.
    await Future<void>.delayed(Duration.zero);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Shared provider overrides: storage-backed providers are pinned to fixed
/// values so the test doesn't depend on Hive/Firebase.
List<Override> appOverrides({required bool introShown}) => [
      themeModeProvider.overrideWith((ref) => ThemeMode.system),
      localeProvider.overrideWith((ref) => 'en'),
      onboardedProvider.overrideWith((ref) => false),
      splashIntroShownProvider.overrideWith((ref) => introShown),
      cloudReadyProvider.overrideWith((ref) => false),
      authProvider.overrideWith((ref) => FakeAuthController()),
    ];

/// Pumps through the full splash intro (played on every launch) into
/// onboarding, draining the exit hold, the route transition and the
/// incoming page's mount timers.
Future<void> pumpToOnboarding(WidgetTester tester) async {
  await tester.pump(); // splash first frame
  await tester.pump(const Duration(milliseconds: 2400)); // intro part 1
  await tester.pump(const Duration(milliseconds: 1600)); // intro + exit hold
  await tester.pump(const Duration(milliseconds: 900)); // hand-off + drain mount timers
}
