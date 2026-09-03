// Widget tests for the redesigned web home screen (HomeScreenWeb).
//
// Locks the responsive redesign in place without needing a signed-in live
// account: hero + stat chips + quick actions render on desktop and narrow
// widths without layout overflow, the recent-uploads grid appears with data,
// and an empty vault shows the invitation state instead of dead sections.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/home/home_screen_web.dart';

import 'helpers.dart';

Painting _paint(String id) => Painting(
  id: id,
  title: 'Art $id',
  artistId: 'a-$id',
  artistName: 'Artist A',
  medium: 'Oil on canvas',
  createdAt: DateTime(2026, 1, 1, 12),
  updatedAt: DateTime(2026, 1, 1, 12),
);

AppUser _user() => AppUser(
  uid: 'u1',
  email: 'a@b.com',
  displayName: 'Tester',
  role: AppRole.curator,
  plan: AppPlan.free,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);

/// Pumps HomeScreenWeb inside the standard fake-provider harness at a given
/// logical surface size. All routes the screen navigates to are stubbed.
Widget _homeApp({required Size surface, required List<Painting> paintings}) {
  final overrides = <Override>[
    ...appOverrides(introShown: true),
    authProvider.overrideWith(
      (ref) => FakeAuthController(
        AuthState(status: AuthStatus.authenticated, user: _user()),
      ),
    ),
    paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
    artistsProvider.overrideWith((ref) => Stream.value(const [])),
    documentsProvider.overrideWith((ref) => Stream.value(const [])),
    storageUsageProvider.overrideWith(
      (ref) async => const StorageUsage(images: 0, documents: 0, exports: 0),
    ),
    deviceStorageProvider.overrideWith((ref) async => null),
    currencyProvider.overrideWith((ref) => 'USD'),
  ];

  return ProviderScope(
    overrides: overrides,
    child: AdaptiveLayout(
      profile: testProfile,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreenWeb()),
            GoRoute(path: '/gallery', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/artists', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/reports', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/painting/new', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/painting/:id', builder: (_, _) => const SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size surface,
    required List<Painting> paintings,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(surface);
    await tester.pumpWidget(_homeApp(surface: surface, paintings: paintings));
    await tester.pump(); // deliver the stream value
    // Let entrances, count-ups and the shimmer sweep finish.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('desktop: hero, stat chips, quick actions and recent grid', (
    tester,
  ) async {
    await pumpHome(
      tester,
      surface: const Size(1400, 1000),
      paintings: [for (var i = 0; i < 6; i++) _paint('p$i')],
    );

    // Hero statement + gradient name.
    expect(find.textContaining('Good '), findsWidgets);
    expect(find.text('Tester'), findsWidgets);

    // CTAs and stat chips.
    expect(find.text('Add artwork'), findsOneWidget);
    expect(find.text('Browse gallery'), findsOneWidget);
    expect(find.text('Artworks'), findsWidgets);
    expect(find.text('Value'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);

    // Quick action band.
    expect(find.text('Upload'), findsWidgets);
    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('Artists'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);

    // Recent uploads section is above the fold; insights live below it in
    // the lazy sliver, so scroll down to it.
    expect(find.text('Recent uploads'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AI Insights'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Drain the staggered tile entrances that scrolling just scheduled.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('narrow: layout stacks and reflows without overflow', (
    tester,
  ) async {
    await pumpHome(
      tester,
      surface: const Size(520, 900),
      paintings: [for (var i = 0; i < 5; i++) _paint('p$i')],
    );

    // Core content still present at phone-ish width.
    expect(find.text('Add artwork'), findsOneWidget);
    expect(find.text('Browse gallery'), findsOneWidget);
    expect(find.text('Recent uploads'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AI Insights'), findsOneWidget);

    // Any RenderFlex overflow or layout crash would surface here.
    expect(tester.takeException(), isNull);

    // Drain the staggered tile entrances that scrolling just scheduled.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('empty vault: invitation state, no dead sections', (
    tester,
  ) async {
    await pumpHome(tester, surface: const Size(1200, 900), paintings: const []);

    // The stage invites the collector to begin.
    expect(find.text('Add your first artwork'), findsOneWidget);
    // No grid/sections without data.
    expect(find.text('Recent uploads'), findsNothing);
    expect(find.text('AI Insights'), findsNothing);
    // CTAs and quick actions still guide the user.
    expect(find.text('Add artwork'), findsOneWidget);
    expect(find.text('Browse gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
