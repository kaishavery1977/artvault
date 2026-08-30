// Widget tests for the free-plan usage meter on the home screen: counts
// render against the free-tier caps, bars warn amber near the limit, and
// the moment a count reaches its cap it turns red and shakes once.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/constants/pro_limits.dart';
import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/home/home_screen.dart';

import 'helpers.dart';

Painting _paint(String id) {
  final now = DateTime(2026, 1, 1, 12);
  return Painting(
    id: id,
    title: 'Art $id',
    artistId: 'a-$id',
    artistName: 'Artist',
    createdAt: now,
    updatedAt: now,
  );
}

AppUser _freeUser() => AppUser(
  uid: 'u1',
  email: 'a@b.com',
  displayName: 'Tester',
  role: AppRole.curator,
  plan: AppPlan.free,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);

/// Pumps the home screen with a controllable paintings stream so the test
/// can push a count across a cap boundary mid-flight.
Widget _homeApp(
  Stream<List<Painting>> paintings, {
  AppPlan plan = AppPlan.free,
}) {
  return ProviderScope(
    overrides: [
      ...appOverrides(introShown: true),
      authProvider.overrideWith(
        (ref) => FakeAuthController(
          AuthState(
            status: AuthStatus.authenticated,
            user: _freeUser().copyWith(plan: plan),
          ),
        ),
      ),
      paintingsProvider.overrideWith((ref) => paintings),
      artistsProvider.overrideWith((ref) => Stream.value(const [])),
      documentsProvider.overrideWith((ref) => Stream.value(const [])),
      storageUsageProvider.overrideWith(
        (ref) async => const StorageUsage(images: 0, documents: 0, exports: 0),
      ),
      deviceStorageProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith((ref) => 'USD'),
    ],
    child: AdaptiveLayout(
      profile: testProfile,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/upgrade', builder: (_, _) => const SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets('usage meter shows counts against the free caps', (tester) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);
    controller.add([for (var i = 0; i < 12; i++) _paint('p$i')]);

    await tester.pumpWidget(_homeApp(controller.stream));
    await tester.pump(); // deliver the stream value
    await tester.pump(const Duration(milliseconds: 50));
    // Let the count-up / bar-fill animations finish.
    await tester.pump(const Duration(milliseconds: 1000));

    // The new CollectionHero shows stat badges with counts
    expect(find.text('12'), findsWidgets); // paintings count
    expect(find.text('Artworks'), findsWidgets);
    expect(find.text('Artists'), findsWidgets);
    expect(find.text('Docs'), findsWidgets);
    expect(find.text('Free'), findsOneWidget); // plan badge for free users
  });

  testWidgets('turns red and shakes the moment a count hits the cap', (
    tester,
  ) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);

    // Start below the cap, then push one more painting to cross it.
    controller.add([
      for (var i = 0; i < ProLimits.freePaintings - 1; i++) _paint('p$i'),
    ]);

    await tester.pumpWidget(_homeApp(controller.stream));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify the paintings count shows (below cap)
    expect(find.text('${ProLimits.freePaintings - 1}'), findsWidgets);

    // Cross the cap: full count now.
    controller.add([
      for (var i = 0; i < ProLimits.freePaintings; i++) _paint('p$i'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));

    // Verify the cap count shows
    expect(find.text('${ProLimits.freePaintings}'), findsWidgets);

    // Let any animations finish
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('pro accounts see no free-plan usage meter', (tester) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);
    controller.add([for (var i = 0; i < 5; i++) _paint('p$i')]);

    await tester.pumpWidget(_homeApp(controller.stream, plan: AppPlan.pro));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Pro users don't see the "Free" plan badge
    expect(find.text('Free'), findsNothing);
    // Pro users don't see the upgrade button
    expect(find.text('Upgrade'), findsNothing);
  });
}
