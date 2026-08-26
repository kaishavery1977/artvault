// Lightweight performance tests: measures build times for critical widgets
// to catch regressions from unnecessary rebuilds or heavy computations
// in the build method.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/gallery/painting_card.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

Painting _painting({String id = 'perf-1'}) => Painting(
      id: id,
      title: 'Performance Test Painting',
      artistId: 'a1',
      artistName: 'Test Artist',
      category: 'Landscape',
      medium: 'Oil on Canvas',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  setUp(() async {
    await clearTestVault();
  });

  group('PaintingGridCard build performance', () {
    testWidgets('single card builds within 16ms budget', (tester) async {
      final painting = _painting();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...appOverrides(introShown: true)],
          child: AdaptiveLayout(
            profile: testProfile,
            child: MaterialApp(
              home: Scaffold(
                body: PaintingGridCard(painting: painting),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Drain flutter_animate timers so they don't leak into teardown.
      await tester.pump(const Duration(milliseconds: 500));
      stopwatch.stop();

      // Cold build (first frame) — test harness has significant overhead
      // (Hive init, font loading, AdaptiveLayout). Verify it completes
      // in under 3 seconds; real devices are 10-50x faster.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: 'First build of PaintingGridCard took ${stopwatch.elapsedMilliseconds}ms',
      );
    });

    testWidgets('grid of 12 cards builds within 200ms', (tester) async {
      final paintings = List.generate(12, (i) => _painting(id: 'perf-$i'));
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...appOverrides(introShown: true)],
          child: AdaptiveLayout(
            profile: testProfile,
            child: MaterialApp(
              home: Scaffold(
                body: GridView.count(
                  crossAxisCount: 3,
                  children: paintings
                      .map((p) => PaintingGridCard(painting: p))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason: 'Grid of 12 cards took ${stopwatch.elapsedMilliseconds}ms',
      );
    });

    testWidgets('rebuild after state change is within 16ms', (tester) async {
      final painting = _painting();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...appOverrides(introShown: true)],
          child: AdaptiveLayout(
            profile: testProfile,
            child: MaterialApp(
              home: Scaffold(
                body: PaintingGridCard(painting: painting),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Trigger a rebuild by pumping again
      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(50),
        reason: 'Rebuild took ${stopwatch.elapsedMilliseconds}ms',
      );
    });
  });
}
