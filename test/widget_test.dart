// Basic Flutter widget test: verifies the app boots to the branded splash
// screen. The app is a Riverpod ConsumerWidget, so it must be pumped inside
// a ProviderScope. The real providers that read local storage (Hive) or
// Firebase are overridden so the test runs without a device or emulator.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/main.dart';
import 'package:artvault/core/providers/providers.dart';

/// Auth controller whose [bootstrap] never touches local/secure storage.
class _FakeAuthController extends AuthController {
  @override
  Future<void> bootstrap() async {
    // Defer past the build phase — modifying a provider inside initState is
    // not allowed by Riverpod.
    await Future<void>.delayed(Duration.zero);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  testWidgets('App boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) => ThemeMode.system),
          localeProvider.overrideWith((ref) => 'en'),
          onboardedProvider.overrideWith((ref) => false),
          cloudReadyProvider.overrideWith((ref) => false),
          authProvider.overrideWith((ref) => _FakeAuthController()),
        ],
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    expect(find.text('ArtVault'), findsOneWidget);

    // Drain the splash screen's startup timer, then give the router time to
    // finish navigating (which starts new finite animations) so no timers are
    // pending when the test ends.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 600));
  });
}
