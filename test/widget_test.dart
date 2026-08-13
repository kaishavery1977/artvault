// Widget tests for the branded boot sequence: full cinematic splash on first
// launch, quick intro on repeat launches, and a static render when the system
// requests reduced motion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/main.dart';

import 'helpers.dart';

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets('App boots to the full splash on first launch',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: false),
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

    // The full intro hands off into onboarding.
    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Repeat launches get the quick intro', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(introShown: true),
        child: const ArtVaultApp(),
      ),
    );
    await tester.pump();

    // Quick variant: the logo mark still does its video-like entrance
    // (spotlight bloom + drop-in) and the wordmark fades — only the
    // cinematic extras (tagline, dot loader) are skipped.
    expect(find.text('Your Private Gallery'), findsNothing);
    // Mid-intro: the palette mark and the first letters are on screen.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.palette), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);

    await pumpToOnboarding(tester);

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });

  testWidgets('Reduced motion shows a static splash and skips the exit',
      (WidgetTester tester) async {
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

    // Static wordmark (single Text, no letter stagger) and no tagline.
    expect(find.text('ArtVault'), findsOneWidget);
    expect(find.text('Your Private Gallery'), findsNothing);

    // 350ms static hold, direct hand-off (no exit), route transition,
    // then drain the onboarding mount timers.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Curate Your Collection'), findsOneWidget);
  });
}
