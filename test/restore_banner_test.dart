// Widget tests for the restore-from-cloud banner on the home screen: it
// shows the current stage while the pipeline runs, switches to a
// dismissible summary when files were restored, and stays hidden when
// nothing was restored (or nothing is running).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/features/home/home_screen.dart';

import 'helpers.dart';

AppUser _user() => AppUser(
      uid: 'u1',
      email: 'a@b.com',
      displayName: 'Tester',
      role: AppRole.curator,
      plan: AppPlan.free,
      createdAt: DateTime(2026),
      lastLogin: DateTime(2026),
    );

/// Pumps the home screen with a pinned restore-progress state.
Widget _homeApp(RestoreProgress? progress) {
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
      if (progress != null)
        restoreProgressProvider.overrideWith((ref) => progress),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/repair-images', builder: (_, _) => const SizedBox()),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets('shows the current stage while the restore is running',
      (tester) async {
    await tester.pumpWidget(
      _homeApp(
        const RestoreProgress(running: true, stage: 'Restoring paintings…'),
      ),
    );
    // Bounded pumps only — the running banner has a spinner, so
    // pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Restoring paintings…'), findsOneWidget);
    expect(
      find.text('Re-downloading your vault — keep the app open'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('switches to a dismissible summary once files were restored',
      (tester) async {
    await tester.pumpWidget(
      _homeApp(
        const RestoreProgress(running: false, stage: 'done', itemsRestored: 3),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Restored 3 files from the cloud'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Dismissing hides the banner.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Restored'), findsNothing);
  });

  testWidgets('stays hidden when nothing was restored or nothing is running',
      (tester) async {
    await tester.pumpWidget(
      _homeApp(
        const RestoreProgress(running: false, stage: 'done', itemsRestored: 0),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Restored'), findsNothing);
    expect(find.textContaining('Restoring'), findsNothing);
  });

  testWidgets('no banner at all when restore is idle', (tester) async {
    await tester.pumpWidget(_homeApp(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Restored'), findsNothing);
    expect(find.textContaining('Restoring'), findsNothing);
  });
}
