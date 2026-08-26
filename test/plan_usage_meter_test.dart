// Widget tests for the free-plan usage meter on the home screen: counts
// render against the free-tier caps, bars warn amber near the limit, and
// the moment a count reaches its cap it turns red and shakes once.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/constants/app_colors.dart';
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
      authProvider.overrideWith((ref) => FakeAuthController(
            AuthState(
              status: AuthStatus.authenticated,
              user: _freeUser().copyWith(plan: plan),
            ),
          )),
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

  testWidgets('usage meter shows counts against the free caps',
      (tester) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);
    controller.add([for (var i = 0; i < 12; i++) _paint('p$i')]);

    await tester.pumpWidget(_homeApp(controller.stream));
    await tester.pump(); // deliver the stream value
    await tester.pump(const Duration(milliseconds: 50));
    // Let the count-up / bar-fill animations finish.
    await tester.pump(const Duration(milliseconds: 1000));

    expect(
      find.text('12 / ${ProLimits.freePaintings}'),
      findsOneWidget,
    );
    // Rows exist for paintings, artists, documents and storage (the label
    // can also appear in the stats grid above, so at least one is enough).
    expect(find.text('Paintings'), findsWidgets);
    expect(find.text('Artists'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Storage'), findsWidgets);
  });

  testWidgets('turns red and shakes the moment a count hits the cap',
      (tester) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);

    // Start below the cap, then push one more painting to cross it.
    controller.add(
      [for (var i = 0; i < ProLimits.freePaintings - 1; i++) _paint('p$i')],
    );

    await tester.pumpWidget(_homeApp(controller.stream));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Let the count-up / bar-fill animations finish so "24 / 25" renders.
    await tester.pump(const Duration(milliseconds: 1000));

    // Below the cap: normal (primary) bar color, no shake.
    final barBefore = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.ancestor(
          of: find.text('${ProLimits.freePaintings - 1} / ${ProLimits.freePaintings}'),
          matching: find.byType(Row),
        ),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(barBefore.color, isNot(AppColors.error));

    // Let the shake animation finish so no timers are pending before the
    // second pump below (the LinearProgressIndicator color is animated by
    // the count-up, which needs settling).
    await tester.pump(const Duration(milliseconds: 600));

    // Cross the cap: full count now.
    controller.add(
      [for (var i = 0; i < ProLimits.freePaintings; i++) _paint('p$i')],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900)); // fill animation

    // Red bar at exactly the cap.
    final barAfter = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.ancestor(
          of: find.text('${ProLimits.freePaintings} / ${ProLimits.freePaintings}'),
          matching: find.byType(Row),
        ),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(barAfter.color, AppColors.error);

    // The shake fired (ShakeOnError mounts a keyed subtree on tick > 0).
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('shake-1')),
      findsOneWidget,
      reason: 'the row should shake once when the cap is crossed',
    );

    // Let the shake animation finish so no timers are pending.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('pro accounts see no free-plan usage meter', (tester) async {
    final controller = StreamController<List<Painting>>();
    addTearDown(controller.close);
    controller.add([for (var i = 0; i < 5; i++) _paint('p$i')]);

    await tester.pumpWidget(_homeApp(controller.stream, plan: AppPlan.pro));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // _PlanUsageCard hides entirely for Pro — unlimited needs no meter.
    expect(find.text('Free plan usage'), findsNothing);
    // The storage ring is also hidden for Pro (no cap to measure against).
    expect(find.textContaining('%'), findsNothing);
  });
}
