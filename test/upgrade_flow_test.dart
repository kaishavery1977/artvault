// Upgrade-flow tests: the Pro button must never silently grant the paid
// entitlement — with no payment method configured it shows an explicit
// confirmation dialog (debug builds), and cancelling leaves the plan free.
// Also covers the Users screen's honest offline banner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/services/pro_billing_service.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/features/pro/upgrade_screen.dart';
import 'package:artvault/features/admin/users_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

AppUser _user(AppPlan plan) => AppUser(
  uid: 'u1',
  email: 'a@b.com',
  displayName: 'Tester',
  role: AppRole.admin,
  plan: plan,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);

Widget _upgradeApp() {
  return ProviderScope(
    overrides: [
      ...appOverrides(introShown: true),
      authProvider.overrideWith(
        (ref) => FakeAuthController(
          AuthState(
            status: AuthStatus.authenticated,
            user: _user(AppPlan.free),
          ),
        ),
      ),
    ],
    child: const MaterialApp(home: UpgradeScreen()),
  );
}

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  setUp(() {
    // The test host reports the store as available by default — force the
    // no-store path so the preview/unlock states render deterministically.
    ProBillingService.debugForceStoreUnavailable = true;
  });

  tearDown(() {
    ProBillingService.debugForceStoreUnavailable = false;
  });

  /// Scrolls the upgrade screen to the CTA card (it sits below the feature
  /// list and is built lazily) and returns after the reveal settles.
  Future<void> revealCta(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Unlock Pro (preview)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('no payment method: tapping Unlock Pro does NOT grant Pro', (
    tester,
  ) async {
    await tester.pumpWidget(_upgradeApp());
    // Let the store-availability probe settle (store is unavailable in
    // tests, Razorpay is not configured → preview path).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await revealCta(tester);

    expect(find.text('Unlock Pro (preview)'), findsOneWidget);

    await tester.tap(find.text('Unlock Pro (preview)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A confirmation dialog appears — Pro is NOT granted silently.
    expect(find.text('Developer preview unlock?'), findsOneWidget);

    // Cancel → still free.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Developer preview unlock?'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpgradeScreen)),
    );
    expect(container.read(authProvider).user?.plan, AppPlan.free);
  });

  testWidgets('confirming the preview unlock grants Pro', (tester) async {
    await tester.pumpWidget(_upgradeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await revealCta(tester);

    await tester.tap(find.text('Unlock Pro (preview)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Activate preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpgradeScreen)),
    );
    expect(container.read(authProvider).user?.plan, AppPlan.pro);
  });

  testWidgets('Users screen shows an offline banner when cloud is down', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appOverrides(introShown: true),
          authProvider.overrideWith(
            (ref) => FakeAuthController(
              AuthState(
                status: AuthStatus.authenticated,
                user: _user(AppPlan.free),
              ),
            ),
          ),
          usersProvider.overrideWith(
            (ref) => Stream.value([_user(AppPlan.free)]),
          ),
        ],
        child: const MaterialApp(home: UsersScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // cloudReadyProvider is overridden to false in appOverrides → the
    // screen must say the list is not the full cloud set.
    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('showing your profile only'), findsOneWidget);
  });
}
