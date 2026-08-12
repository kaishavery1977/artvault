// Onboarding flow tests: the skip hand-off into login, the Next/Get Started
// walkthrough, and the static render under reduced motion. These exercise the
// finish path end-to-end, so LocalDatabase is initialized through the Hive
// harness (the login screen probes biometric settings on mount).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/main.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestHive();
    disableRuntimeFontFetching();
  });

  testWidgets('Skip hands off into login and marks onboarding done',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await pumpToOnboarding(tester);
    expect(find.text('Curate Your Collection'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    // Router transition (280ms), then drain the login screen's staggered
    // field reveal (~1.4s of delay+animation timers).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text("Don't have an account?"), findsOneWidget);
  });

  testWidgets('Next walks through all slides then Get Started finishes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await pumpToOnboarding(tester);
    expect(find.text('Curate Your Collection'), findsOneWidget);

    // Page animation: first pump starts the ticker, second completes it.
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('AI-Powered Insight'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Secure & Offline-First'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text("Don't have an account?"), findsOneWidget);
  });

  testWidgets('Reduced motion renders onboarding statically',
      (WidgetTester tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();
    // 350ms static splash + direct hand-off + route transition.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Curate Your Collection'), findsOneWidget);

    // A static render leaves no animation timers pending.
    await tester.pump(const Duration(milliseconds: 100));
  });
}
