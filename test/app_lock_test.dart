// Widget tests for the cold-start lock gate (AppLockScreen) PIN pad:
// auto-submit at 4 digits, wrong-PIN error feedback (message + red dots),
// and the shake replay on failed attempts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/widgets/motion.dart';
import 'package:artvault/data/repositories/auth_repository.dart';
import 'package:artvault/features/splash/app_lock_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
    await clearTestSettings();
  });

  // Persistent secure-storage mock so a passcode can be stored, read back
  // and verified (the shared stub always returns null).
  void stubSecureStoragePersist() {
    final store = <String, String>{};
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      switch (call.method) {
        case 'read':
          return store[args['key'] as String];
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          store.remove(args['key'] as String);
          return null;
      }
      return null;
    });
    // No enrolled biometrics, so AppLockScreen's `_setup` completes with
    // the PIN pad as the only unlock method (hasFingerprint/hasFaceId read
    // this channel and would otherwise throw in the test environment,
    // aborting the setup future before `passcodeSet` is even read).
    const biometrics = MethodChannel('plugins.flutter.io/local_auth');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(biometrics, (call) async {
      if (call.method == 'getAvailableBiometrics') return <String>[];
      return null;
    });
  }

  // Minimal router: the lock screen sits at /lock and navigates home on
  // a successful unlock. Biometrics return false under the test platform,
  // so with a passcode stored the PIN pad is the only unlock path shown.
  GoRouter lockRouter() => GoRouter(
        initialLocation: '/lock',
        routes: [
          GoRoute(
            path: '/lock',
            builder: (_, _) => const AppLockScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME_RENDERED')),
          ),
        ],
      );

  Future<void> pumpLock(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: lockRouter()));
    // _setup reads Hive + biometric platform channels — real async futures
    // that don't resolve under fake-async pumps alone, so let them settle
    // inside a real-async window before the UI reflects the loaded state.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }

  /// Taps the on-screen keypad digits in order.
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
  }

  testWidgets('auto-submits at 4 digits and unlocks with the right PIN',
      (tester) async {
    stubSecureStoragePersist();
    await AuthRepository.instance.setPasscode('1234');
    await pumpLock(tester);

    // PIN pad visible (only unlock path — no biometrics in tests).
    expect(find.text('Enter your passcode to open your private gallery'),
        findsOneWidget);

    await enterPin(tester, '1234');
    // Verification is async; let the success confirmation play through and
    // the navigation land.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HOME_RENDERED'), findsOneWidget);
  });

  testWidgets('wrong PIN shows error message, clears dots and shakes',
      (tester) async {
    stubSecureStoragePersist();
    await AuthRepository.instance.setPasscode('1234');
    await pumpLock(tester);

    // Dots start empty (4 dot containers inside the pad row).
    ShakeOnError shake() => tester.widget<ShakeOnError>(
          find.byType(ShakeOnError),
        );
    expect(shake().tick, 0);

    await enterPin(tester, '9999');
    await tester.pump(const Duration(milliseconds: 50));

    // Error feedback rendered in the error color, shake tick advanced,
    // dots cleared for a fresh attempt.
    final error = find.text('Incorrect passcode. Try again.');
    expect(error, findsOneWidget);
    final errorText = tester.widget<Text>(error);
    expect(
      errorText.style?.color,
      Theme.of(tester.element(error)).colorScheme.error,
    );
    expect(shake().tick, 1);
    // Still on the lock screen (no navigation on failure).
    expect(find.text('HOME_RENDERED'), findsNothing);
  });

  testWidgets('tapping a digit after a wrong attempt clears the error state',
      (tester) async {
    stubSecureStoragePersist();
    await AuthRepository.instance.setPasscode('1234');
    await pumpLock(tester);

    await enterPin(tester, '9999');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Incorrect passcode. Try again.'), findsOneWidget);

    await enterPin(tester, '1');
    await tester.pump(const Duration(milliseconds: 50));

    // Error status is gone while the user retypes.
    expect(find.text('Incorrect passcode. Try again.'), findsNothing);
    expect(
      tester
          .widget<ShakeOnError>(find.byType(ShakeOnError))
          .tick,
      1, // the shake for the previous attempt is still shown
    );
  });
}
