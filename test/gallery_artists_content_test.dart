// Regression tests for the premium content pass on gallery + artists:
// differentiated empty states, select-mode chrome (ring check, sync-badge
// hiding), and the artists loading skeleton.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/core/widgets/motion.dart';
import 'package:artvault/data/models/artist.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/artists/artists_screen.dart';
import 'package:artvault/features/gallery/gallery_screen.dart';
import 'package:artvault/features/gallery/painting_card.dart';

import 'helpers.dart';

Painting _painting(String id, String title) {
  final now = DateTime(2026, 1, 1, 12);
  return Painting(
    id: id,
    title: title,
    artistId: 'a-$id',
    artistName: 'Ravi',
    createdAt: now,
    updatedAt: now,
  );
}

Artist _artist(String id, String name) {
  final now = DateTime(2026, 1, 1, 12);
  return Artist(id: id, name: name, createdAt: now, updatedAt: now);
}

Widget _galleryApp(List<Painting> paintings) {
  return ProviderScope(
    overrides: [
      paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
      artistsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: AdaptiveLayout(
      profile: testProfile,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/gallery',
          routes: [
            GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
          ],
        ),
      ),
    ),
  );
}

Widget _artistsApp(
  Stream<List<Artist>> artists, {
  List<Painting> paintings = const [],
}) {
  return ProviderScope(
    overrides: [
      paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
      artistsProvider.overrideWith((ref) => artists),
    ],
    child: AdaptiveLayout(
      profile: testProfile,
      child: const MaterialApp(home: ArtistsScreen()),
    ),
  );
}

void main() {
  group('gallery content pass', () {
    testWidgets('bare vault shows the upload empty state', (tester) async {
      await tester.pumpWidget(_galleryApp(const []));
      await tester.pump();

      expect(find.text('No artworks here yet'), findsOneWidget);
      expect(find.text('Add painting'), findsOneWidget);
      // Drain entrance animations (header + empty state).
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('favorites filter explains itself and clears back', (
      tester,
    ) async {
      await tester.pumpWidget(_galleryApp([_painting('p1', 'Sunset Study')]));
      await tester.pump();

      // Heart the favorites filter on with no favorites marked. The header
      // toggle is the first favorite_border in tree order (cards follow).
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.text('Browse gallery'), findsOneWidget);

      // The action resolves the filter and restores the grid.
      await tester.tap(find.text('Browse gallery'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Sunset Study'), findsOneWidget);
      // Drain the grid entrance timers.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('select mode shows checks and hides the sync badge', (
      tester,
    ) async {
      final paintings = [
        _painting('p1', 'Sunset Study'),
        _painting('p2', 'Blue Hour'),
        _painting('p3', 'Golden Field'),
      ];
      await tester.pumpWidget(_galleryApp(paintings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Unsynced paintings carry a sync badge before selection.
      expect(find.byIcon(Icons.sync), findsWidgets);

      // Long-press enters select mode with the first card selected.
      await tester.longPress(find.byType(PaintingGridCard).first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
      // Cloud chrome is noise during batch ops — badge yields to the check.
      expect(find.byIcon(Icons.sync), findsNothing);

      // Tapping another card selects it too.
      await tester.tap(find.byType(PaintingGridCard).at(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });
  });

  group('artists content pass', () {
    testWidgets('loading shows the skeleton, not a false empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_artistsApp(const Stream<List<Artist>>.empty()));
      await tester.pump();

      // Never-delivered stream: still loading, so no empty-state copy yet.
      expect(find.text('No artists yet'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('empty roster shows premium copy', (tester) async {
      await tester.pumpWidget(_artistsApp(Stream.value(const [])));
      await tester.pump();

      expect(find.text('No artists yet'), findsOneWidget);
      expect(find.textContaining('first painting'), findsOneWidget);
      // Drain the EmptyState entrance animation.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('roster cards carry the tilt + lift hover primitives', (
      tester,
    ) async {
      await tester.pumpWidget(
        _artistsApp(
          Stream.value([_artist('a1', 'Ravi Varma'), _artist('a2', 'Amrita')]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Ravi Varma'), findsOneWidget);
      expect(find.text('Amrita'), findsOneWidget);
      expect(find.byType(TiltCard), findsNWidgets(2));
      expect(find.byType(HoverLift), findsNWidgets(2));
    });
  });
}
