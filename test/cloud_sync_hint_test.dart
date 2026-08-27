// Widget tests for the subtle "cloud sync unavailable" hint on the home
// screen: it appears once the failed-upload streak passes the threshold
// (CloudBackend.uploadFailureHintAfter), and stays hidden on a clean streak
// or a rare single blip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/remote/cloud_backend.dart';
import 'package:artvault/features/home/home_screen.dart';

import 'helpers.dart';

class _FakeCloudSyncHealth extends CloudSyncHealthNotifier {
  _FakeCloudSyncHealth(this.streak);
  final int streak;

  @override
  int build() => streak;
}

AppUser _user() => AppUser(
  uid: 'u1',
  email: 'a@b.com',
  displayName: 'Tester',
  role: AppRole.curator,
  plan: AppPlan.free,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);

Widget _homeApp(int failedUploads) {
  return ProviderScope(
    overrides: [
      ...appOverrides(introShown: true),
      authProvider.overrideWith(
        (ref) => FakeAuthController(
          AuthState(status: AuthStatus.authenticated, user: _user()),
        ),
      ),
      paintingsProvider.overrideWith((ref) => Stream.value(const [])),
      artistsProvider.overrideWith((ref) => Stream.value(const [])),
      documentsProvider.overrideWith((ref) => Stream.value(const [])),
      storageUsageProvider.overrideWith(
        (ref) async => const StorageUsage(images: 0, documents: 0, exports: 0),
      ),
      deviceStorageProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith((ref) => 'USD'),
      cloudSyncHealthProvider.overrideWith(
        () => _FakeCloudSyncHealth(failedUploads),
      ),
    ],
    child: AdaptiveLayout(
      profile: testProfile,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(
              path: '/repair-images',
              builder: (_, _) => const SizedBox(),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets('shows the hint once the failed-upload streak passes the '
      'threshold', (tester) async {
    await tester.pumpWidget(_homeApp(CloudBackend.uploadFailureHintAfter));
    // Extra bounded pump lets flutter_animate's zero-duration timers fire,
    // so no timers are left pending at teardown.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud sync unavailable — tap to retry'), findsOneWidget);
  });

  testWidgets('hides the hint on a clean streak', (tester) async {
    await tester.pumpWidget(_homeApp(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud sync unavailable — tap to retry'), findsNothing);
  });

  testWidgets('hides the hint on a single rare blip', (tester) async {
    await tester.pumpWidget(_homeApp(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud sync unavailable — tap to retry'), findsNothing);
  });

  testWidgets('dismissing hides the hint', (tester) async {
    await tester.pumpWidget(_homeApp(CloudBackend.uploadFailureHintAfter));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud sync unavailable — tap to retry'), findsNothing);
  });

  testWidgets('a successful sync un-dismisses so the hint can return', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp(CloudBackend.uploadFailureHintAfter));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Cloud sync unavailable — tap to retry'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    // A sync succeeded — streak back to 0.
    container.read(cloudSyncHealthProvider.notifier).state = 0;
    await tester.pump();
    // Failures accumulate again — the hint returns.
    container.read(cloudSyncHealthProvider.notifier).state =
        CloudBackend.uploadFailureHintAfter;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud sync unavailable — tap to retry'), findsOneWidget);
  });
}
