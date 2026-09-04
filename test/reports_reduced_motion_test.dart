// Regression tests for the Reports content pass + the reduced-motion audit:
// the reports loading skeleton (no false-zero summary), the empty-vault
// state (role-aware CTA, exports hidden), the export IconWell rhythm, and
// the new reduced-motion gates on shared primitives (AnimatedCountUp,
// GlassCard entrances, AuroraBackground).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/core/widgets/bits.dart';
import 'package:artvault/core/widgets/motion.dart';
import 'package:artvault/core/widgets/surfaces.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/artist.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/reports/reports_screen.dart';

import 'helpers.dart';

Painting _painting(
  String id,
  String title, {
  double? price,
  String medium = 'Oil on canvas',
}) {
  final now = DateTime(2026, 1, 1, 12);
  return Painting(
    id: id,
    title: title,
    artistId: 'a-$id',
    artistName: 'Ravi',
    createdAt: now,
    updatedAt: now,
    price: price,
    medium: medium,
  );
}

Widget _reportsApp({
  required Stream<List<Painting>> paintings,
  required Stream<List<Artist>> artists,
  required AppRole role,
}) {
  return ProviderScope(
    overrides: [
      paintingsProvider.overrideWith((ref) => paintings),
      artistsProvider.overrideWith((ref) => artists),
      currencyProvider.overrideWith((ref) => 'USD'),
      authProvider.overrideWith(
        (ref) => FakeAuthController(
          AuthState(
            status: AuthStatus.authenticated,
            user: AppUser(
              uid: 'u1',
              email: 'u@test.dev',
              displayName: 'Tester',
              role: role,
              plan: AppPlan.free,
              createdAt: DateTime(2026),
              lastLogin: DateTime(2026),
            ),
          ),
        ),
      ),
    ],
    child: AdaptiveLayout(
      profile: testProfile,
      child: const MaterialApp(home: ReportsScreen()),
    ),
  );
}

/// Wrapper that toggles the platform reduced-motion flag for primitive tests.
Widget _motionApp({required bool reduce, required Widget child}) {
  return MaterialApp(
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: appChild!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('reports content pass', () {
    testWidgets('loading shows a shimmer skeleton, not zeroed stats', (
      tester,
    ) async {
      await tester.pumpWidget(
        _reportsApp(
          // A never-completing stream keeps the provider in its loading
          // state — the first-paint skeleton must render.
          paintings: const Stream<List<Painting>>.empty(),
          artists: const Stream<List<Artist>>.empty(),
          role: AppRole.curator,
        ),
      );
      await tester.pump();

      expect(find.byType(Shimmer), findsWidgets);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text('Total value'), findsNothing);
      expect(find.text('No collection data yet'), findsNothing);
      expect(find.text('Export & print'), findsNothing);
    });

    testWidgets('empty vault: editor sees the CTA, exports are hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        _reportsApp(
          paintings: Stream.value(const <Painting>[]),
          artists: Stream.value(const <Artist>[]),
          role: AppRole.curator,
        ),
      );
      // Drain the empty-state entrance so no animation timer is pending.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('No collection data yet'), findsOneWidget);
      expect(find.text('Add your first painting'), findsOneWidget);
      expect(find.text('Total value'), findsNothing);
      expect(find.text('Export & print'), findsNothing);
    });

    testWidgets('empty vault: viewer gets copy without an add CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _reportsApp(
          paintings: Stream.value(const <Painting>[]),
          artists: Stream.value(const <Artist>[]),
          role: AppRole.viewer,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('No collection data yet'), findsOneWidget);
      expect(find.text('Add your first painting'), findsNothing);
    });

    testWidgets('populated vault: summary, export rows and icon rhythm', (
      tester,
    ) async {
      // Tall viewport so the lazy sliver builds the whole column — the
      // breakdown, insights and export rows sit below the fold on a
      // phone-sized test surface.
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _reportsApp(
          paintings: Stream.value([
            _painting('p1', 'Monsoon', price: 45000),
            _painting('p2', 'Still Life'),
          ]),
          artists: Stream.value([
            Artist(
              id: 'a-p1',
              name: 'Ravi',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          ]),
          role: AppRole.curator,
        ),
      );
      await tester.pump();
      // Let the staggered entrance finish so nothing hides behind an
      // opacity-0 gate mid-assert.
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('Total value'), findsOneWidget);
      expect(find.text('Artworks'), findsOneWidget);
      // The curator analytics readout renders on non-web too.
      expect(find.text('AI Collection Analytics'), findsOneWidget);

      // Export section is present when the vault holds artwork, and each
      // of the six actions leads with an IconWell.
      expect(find.text('Export & print'), findsOneWidget);
      expect(find.text('PDF catalogue'), findsOneWidget);
      expect(
        find.byType(IconWell),
        findsNWidgets(9), // 2 bar-card headers + 1 insights + 6 export rows
      );
    });
  });

  group('reduced-motion audit', () {
    testWidgets('AnimatedCountUp jumps straight to the final value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _motionApp(
          reduce: true,
          child: AnimatedCountUp(
            value: 42,
            format: (v) => v.round().toString(),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      // It must never show the 0 start and never morph.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('GlassCard renders fully visible on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _motionApp(
          reduce: true,
          child: GlassCard(
            child: Builder(builder: (context) => Text('Card body')),
          ),
        ),
      );

      expect(find.text('Card body'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
        findsNothing,
      );
    });

    testWidgets('AuroraBackground mounts statically under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _motionApp(
          reduce: true,
          child: const SizedBox(
            width: 300,
            height: 300,
            child: AuroraBackground(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AuroraBackground), findsOneWidget);
      // Swap the tree so the (never-started) ticker disposes cleanly.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
