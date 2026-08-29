import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/main.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  testWidgets('App boots to the full splash on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: false),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    // Wordmark letters + tagline visible during intro.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(find.text('Your Private Gallery'), findsOneWidget);

    // Drain the snappy 1500ms intro + 350ms exit + route transition.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Every launch plays the full cinematic intro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Your Private Gallery'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);

    await pumpToOnboarding(tester);

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Returning from background stays on current screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await pumpToOnboarding(tester);
    expect(find.text('Curate Your Collection'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Transient overlays (inactive) do not trigger state change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await pumpToOnboarding(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Reduced motion shows a static splash and skips the exit', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: false),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    expect(find.text('ArtVault'), findsOneWidget);
    expect(find.text('Your Private Gallery'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });
}
