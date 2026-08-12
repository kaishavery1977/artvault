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

    // The wordmark reveals letter-by-letter, so each letter is its own Text
    // — assert on the letters rather than the joined string.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(find.text('Your Private Gallery'), findsOneWidget);

    // Drain the splash screen's intro (3400ms) and push-out exit (560ms),
    // then give the router time to navigate to onboarding (its route
    // transition is 280ms). The final pump drains the delay timers the
    // incoming page's reveal animations create on mount (longest is 700ms),
    // so nothing is pending when the test ends.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 900));
  });
}
