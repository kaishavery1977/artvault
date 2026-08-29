// Widget tests for the branded boot sequence: the icon-on-black splash
// with a purple glow on every launch, and a reduced-motion static render.

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

  testWidgets('App boots to the icon splash on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: false),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    // The splash shows the palette icon and the "ArtVault" wordmark.
    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    expect(find.text('ArtVault'), findsOneWidget);

    // Drain the splash screen's intro (2200ms) and fade-out exit (450ms),
    // then give the router time to navigate to onboarding.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 900));

    // The splash hands off into onboarding.
    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Every launch plays the icon splash intro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    // Repeat launches get the same icon splash (shorter cut).
    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    expect(find.text('ArtVault'), findsOneWidget);

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

    // Background the app (like switching apps), then bring it back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The app stays on the current screen — no splash replay.
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

    // A notification shade pull only moves through inactive — stays put.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // App stays on the current screen.
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

    // Static icon + wordmark on black background, no tagline.
    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    expect(find.text('ArtVault'), findsOneWidget);
    expect(find.text('Your Private Gallery'), findsNothing);

    // 200ms static hold, direct hand-off (no exit), route transition,
    // then drain the onboarding mount timers.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });
}
