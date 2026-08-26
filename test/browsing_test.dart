import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/gallery/gallery_screen.dart';
import 'package:artvault/features/gallery/painting_card.dart';
import 'package:artvault/features/gallery/search_screen.dart';
import 'package:artvault/features/painting/painting_lightbox_screen.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';

import 'helpers.dart';

Painting _painting(String id, String title, {String artist = 'Ravi'}) {
  final now = DateTime(2026, 1, 1, 12);
  return Painting(
    id: id,
    title: title,
    artistId: 'a-$id',
    artistName: artist,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _searchApp(List<Painting> paintings) {
  return ProviderScope(
    overrides: [
      paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
      artistsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: AdaptiveLayout(profile: testProfile, child: const MaterialApp(home: SearchScreen())),
  );
}

void main() {
  group('instant search', () {
    testWidgets('debounces input and updates results live', (tester) async {
      await tester.pumpWidget(_searchApp([
        _painting('p1', 'Sunset Study'),
        _painting('p2', 'Blue Hour'),
      ]));
      await tester.pump(); // let the providers deliver

      // Suggestions show before any query.
      expect(find.text('Smart search'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sunset');

      // Before the debounce elapses the screen still shows suggestions.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Smart search'), findsOneWidget);
      expect(find.text('Sunset Study'), findsNothing);

      // Past the debounce, the match appears without pressing Search.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Smart search'), findsNothing);
      expect(find.text('Sunset Study'), findsOneWidget);
    });

    testWidgets('clearing the field returns to suggestions', (tester) async {
      await tester.pumpWidget(_searchApp([
        _painting('p1', 'Sunset Study'),
      ]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'sunset');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Sunset Study'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Smart search'), findsOneWidget);

      // Drain any short-lived pending timers before the tree is torn down.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('lightbox', () {
    testWidgets('hero tag and counter follow the initial painting',
        (tester) async {
      final paintings = [
        _painting('p1', 'Sunset Study'),
        _painting('p2', 'Blue Hour'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: PaintingLightboxScreen(
          paintings: paintings,
          initialIndex: 1,
        ),
      ));
      await tester.pump();

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'painting-p2');
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('swiping updates the hero tag and counter', (tester) async {
      final paintings = [
        _painting('p1', 'Sunset Study'),
        _painting('p2', 'Blue Hour'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: PaintingLightboxScreen(
          paintings: paintings,
          initialIndex: 0,
        ),
      ));
      await tester.pump();

      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'painting-p1');

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'painting-p2');
      expect(find.text('2 / 2'), findsOneWidget);
    });
  });

  group('gallery grid', () {
    testWidgets('renders painting cards with a staggered entrance',
        (tester) async {
      final paintings = [
        _painting('p1', 'Sunset Study'),
        _painting('p2', 'Blue Hour'),
        _painting('p3', 'Golden Field'),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/gallery',
            routes: [
              GoRoute(
                path: '/gallery',
                builder: (_, _) => const GalleryScreen(),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PaintingGridCard), findsNWidgets(3));
      expect(find.text('Sunset Study'), findsOneWidget);

      // Fire the staggered entrance delays (up to ~390ms of animations).
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}
