// Widget test for the AppLockScreen FACE path: when the face scan pops with
// `true`, the lock screen must run the success confirmation and navigate
// home. The camera/ML pipeline is replaced with a stub route that pops
// `true`, isolating the lock screen's push round-trip + navigation logic.

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/data/repositories/auth_repository.dart';
import 'package:artvault/features/splash/app_lock_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

/// Stands in for the real FaceScanScreen: pops `true` (face matched) after a
/// short delay, exactly like the verify-success path does.
class _ScanPopsTrue extends StatefulWidget {
  const _ScanPopsTrue();

  @override
  State<_ScanPopsTrue> createState() => _ScanPopsTrueState();
}

class _ScanPopsTrueState extends State<_ScanPopsTrue> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('FAKE_SCAN'));
}

/// Persistent secure-storage mock (same pattern as app_lock_test) so the
/// face embedding can be stored and read back.
void stubSecureStoragePersist() {
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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
  // A face biometric is enrolled (and no fingerprint): with the test
  // platform forced to iOS, hasFaceId reads this channel — so the face
  // method is the ONLY unlock path and _setup auto-starts it. (On Android
  // hasFaceId would query the camera plugin, whose Pigeon chain can't be
  // mocked in a widget test.)
  const biometrics = MethodChannel('plugins.flutter.io/local_auth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(biometrics, (call) async {
        if (call.method == 'getAvailableBiometrics') return <String>['face'];
        return null;
      });
}

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
    await clearTestSettings();
  });

  GoRouter lockRouter() => GoRouter(
    initialLocation: '/lock',
    routes: [
      GoRoute(path: '/lock', builder: (_, _) => const AppLockScreen()),
      GoRoute(path: '/face-scan', builder: (_, _) => const _ScanPopsTrue()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME_RENDERED')),
      ),
    ],
  );

  Future<void> pumpLock(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: lockRouter()));
    // _setup reads Hive + platform channels — real async futures that don't
    // resolve under fake-async pumps alone.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }

  testWidgets('face scan success unlocks and navigates home', (tester) async {
    stubSecureStoragePersist();
    // Force the iOS platform so hasFaceId resolves through local_auth (the
    // face biometric enrolled above) instead of the unmockable camera.
    // Reset synchronously at the end of the body — flutter_test's invariant
    // check requires debug variables to be unset before teardown runs.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    // Hive writes are real async IO — they never complete under fake-async
    // pumps, so set the flag inside a runAsync window. The embedding write
    // goes through the mocked secure-storage channel and resolves either way.
    await tester.runAsync(
      () => AuthRepository.instance.setFaceLockEnabled(true),
    );
    await tester.runAsync(
      () => AuthRepository.instance.saveFaceEmbedding([0.5, -0.25, 0.75]),
    );

    debugPrint('DBG before pumpLock');
    await pumpLock(tester);
    // Give the router a few frames to mount the pushed scan route.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The only unlock method is face, so _setup auto-starts the scan.
    expect(find.text('FAKE_SCAN'), findsOneWidget);

    // Stub pops true → success confirmation → navigate home (~1.5s total).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HOME_RENDERED'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
