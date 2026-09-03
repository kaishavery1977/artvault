// Shared helpers for widget tests: provider overrides that keep storage and
// Firebase out of the picture, plus pump helpers for the boot sequence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/core/services/device_resolution_service.dart';

/// No-op: google_fonts was removed from the project. Kept for backward
/// compatibility with existing test files that call this.
void disableRuntimeFontFetching() {}

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

/// Default test device profile (standard phone, 393dp, portrait).
final testProfile = DeviceProfile(
  widthDp: 393,
  heightDp: 852,
  devicePixelRatio: 3.0,
  widthPx: 1179,
  heightPx: 2556,
  shortestSide: 393,
  size: DeviceSize.standard,
  scaleFactor: 1.0,
  fontScale: 1.0,
  isHighDensity: true,
  isLandscape: false,
  capturedAt: DateTime(2026),
);

/// Wraps a widget with AdaptiveLayout so context.scaled() and friends work.
Widget wrapWithAdaptiveLayout(Widget child) {
  return AdaptiveLayout(
    profile: testProfile,
    child: MaterialApp(home: child),
  );
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
  await tester.pump(const Duration(milliseconds: 2300)); // intro
  await tester.pump(const Duration(milliseconds: 700)); // exit hold + drain
  await tester.pump(
    const Duration(milliseconds: 900),
  ); // hand-off + mount timers
  await tester.pump(const Duration(milliseconds: 500)); // extra drain
  await tester.pump(const Duration(milliseconds: 500)); // extra drain
}
