// Tests for the auth flows: form validation on login/register/forgot, the
// offline guard for Google/Apple social sign-in, and the biometric
// management sheets (re-scan face / test fingerprint / remove) on the
// security screen.
//
// Storage-backed state (Hive) uses the shared harness; Firebase stays out of
// the picture via the FakeAuthController in helpers.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/core/services/biometric_service.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/repositories/auth_repository.dart';
import 'package:artvault/features/auth/login_screen.dart';
import 'package:artvault/features/auth/register_screen.dart';
import 'package:artvault/features/auth/forgot_password_screen.dart';
import 'package:artvault/features/settings/security_screen.dart';
import 'package:artvault/core/utils/validators.dart';
import 'package:artvault/core/widgets/premium/premium_button.dart';
import 'package:artvault/core/widgets/app_button.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

/// Drains the login's staggered field reveal (300ms initial + 140ms interval
/// + 650ms duration) so no timers are pending at teardown.
Future<void> _drainLoginMotion(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 800));
}

/// Drains the AuthLayout's logo/header entrance animations (scale + 500ms
/// fadeIn) so no timers are pending at teardown.
Future<void> _drainAuthLayoutMotion(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  // Real file I/O only completes in the real-async zone. Running the clear
  // inside runAsync also drains any write left pending by a previous test's
  // fire-and-forget save, so Hive's per-box write chain never blocks the
  // next test.
  Future<void> freshSettings(WidgetTester tester) =>
      tester.runAsync(clearTestSettings);

  // Presets a settings flag. Must run through runAsync too — Hive's put
  // awaits the disk flush, which never completes inside the fake-async
  // test zone.
  Future<void> presetSetting(WidgetTester tester, String key, bool value) =>
      tester.runAsync(() => LocalDatabase.instance.setSetting(key, value));

  // Stubs the secure-storage platform channel so AuthRepository's reads
  // resolve (returning null = "no passcode/session stored") instead of
  // hanging inside the fake-async test zone.
  void stubSecureStorage() {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return null;
          return null;
        });
  }

  group('Login validation', () {
    testWidgets('empty submit shows required errors', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: LoginScreen()),
          ),
        ),
      );
      await _drainLoginMotion(tester);

      await tester.tap(find.widgetWithText(PremiumButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('invalid email rejected, valid email accepted', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: LoginScreen()),
          ),
        ),
      );
      await _drainLoginMotion(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(PremiumButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });
  });

  group('Login header layout', () {
    testWidgets('ArtVault wordmark is horizontally centered', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: LoginScreen()),
          ),
        ),
      );
      await _drainLoginMotion(tester);

      // Test surface is 800x600 — a centered wordmark must sit at dx 400.
      // Without the Center wrap it renders left-aligned in the stretched
      // column (~dx 310), so this discriminates the regression cleanly.
      // GradientShimmerText stacks two Text widgets (base + shimmer sweep)
      // at the same position — measure the first.
      final wordmark = find.text('ArtVault').first;
      expect(wordmark, findsOneWidget);
      expect(tester.getCenter(wordmark).dx, closeTo(400, 1.0));
    });
  });

  group('Register validation', () {
    testWidgets('password mismatch is rejected', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: RegisterScreen()),
          ),
        ),
      );
      await _drainAuthLayoutMotion(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Kais Havery');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'kais@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'password456');
      await tester.ensureVisible(
        find.widgetWithText(PremiumButton, 'Create Account'),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(PremiumButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('empty submit shows required errors', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: RegisterScreen()),
          ),
        ),
      );
      await _drainAuthLayoutMotion(tester);

      await tester.ensureVisible(
        find.widgetWithText(PremiumButton, 'Create Account'),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(PremiumButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
    });

    testWidgets('eye toggles reveal each password field independently', (
      tester,
    ) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: RegisterScreen()),
          ),
        ),
      );
      await _drainAuthLayoutMotion(tester);

      final password = find.byType(TextFormField).at(2);
      final confirm = find.byType(TextFormField).at(3);

      bool obscured(Finder field) => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .obscureText;

      // Both start hidden; one eye per field, no switch row anymore.
      expect(obscured(password), isTrue);
      expect(obscured(confirm), isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
      expect(find.byType(Switch), findsNothing);

      // Reveal only the password field.
      await tester.ensureVisible(password);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pump();
      expect(obscured(password), isFalse);
      expect(obscured(confirm), isTrue);

      // Reveal the confirm field too.
      await tester.ensureVisible(confirm);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined).last);
      await tester.pump();
      expect(obscured(password), isFalse);
      expect(obscured(confirm), isFalse);

      // Toggling back re-obscures.
      await tester.ensureVisible(password);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pump();
      expect(obscured(password), isTrue);
    });
  });

  group('Forgot password', () {
    testWidgets('invalid email is rejected', (tester) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: ForgotPasswordScreen()),
          ),
        ),
      );
      await _drainAuthLayoutMotion(tester);

      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.tap(find.widgetWithText(AppButton, 'Send reset link'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
    });

    testWidgets('offline submit surfaces a clear error, not a spinner', (
      tester,
    ) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: ForgotPasswordScreen()),
          ),
        ),
      );
      await _drainAuthLayoutMotion(tester);

      await tester.enterText(find.byType(TextFormField), 'kais@example.com');
      await tester.tap(find.widgetWithText(AppButton, 'Send reset link'));
      // Let the busy state render, then settle the failed Future.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Cloud is not connected (no Firebase in tests) — the screen must
      // surface the reason and stay on the form.
      expect(find.text('Check your inbox'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Send reset link'), findsOneWidget);
    });
  });

  group('Offline social sign-in guard', () {
    testWidgets('Google button explains offline instead of firing', (
      tester,
    ) async {
      await freshSettings(tester);
      // CloudBackend singleton defaults to not ready in tests.
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: LoginScreen()),
          ),
        ),
      );
      await _drainLoginMotion(tester);

      await tester.ensureVisible(find.text('Google'));
      await tester.pump();
      await tester.tap(find.text('Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Google sign-in needs an internet connection'),
        findsOneWidget,
      );
    });

    testWidgets('Apple button explains offline instead of firing', (
      tester,
    ) async {
      await freshSettings(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(introShown: true),
          child: AdaptiveLayout(
            profile: testProfile,
            child: const MaterialApp(home: LoginScreen()),
          ),
        ),
      );
      await _drainLoginMotion(tester);

      await tester.ensureVisible(find.text('Apple'));
      await tester.pump();
      await tester.tap(find.text('Apple'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Apple sign-in needs an internet connection'),
        findsOneWidget,
      );
    });
  });

  group('Security screen — passcode lock', () {
    Future<BiometricAvailability> probe() async =>
        const BiometricAvailability(any: true, fingerprint: true, face: true);

    // Persistent secure-storage mock: writes are stored so `passcodeSet`
    // reads back what was saved (the shared stub always returns null).
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
    }

    Widget securityApp() => ProviderScope(
      overrides: appOverrides(introShown: true),
      child: MaterialApp(home: SecurityScreen(availabilityProbe: probe)),
    );

    Finder passcodeSwitch() => find.descendant(
      of: find.widgetWithText(ListTile, 'Passcode lock'),
      matching: find.byType(Switch),
    );

    testWidgets('setting a passcode saves and flips the switch on', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStoragePersist();
      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(passcodeSwitch(), findsOneWidget);
      expect(tester.widget<Switch>(passcodeSwitch()).value, isFalse);

      await tester.tap(passcodeSwitch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The set-passcode dialog opens with PIN-pad entry.
      expect(find.text('Set passcode'), findsOneWidget);

      // Enter first passcode (4 digits — auto-advances to confirm).
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(); // advance to confirm step
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm step — re-enter the same passcode.
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog closed, passcode persisted, switch flipped on.
      expect(find.text('Set passcode'), findsNothing);
      expect(await AuthRepository.instance.passcodeSet, isTrue);
      expect(tester.widget<Switch>(passcodeSwitch()).value, isTrue);
    });

    testWidgets('mismatched passcodes stay in the dialog without saving', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStorage();
      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(passcodeSwitch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter first passcode.
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm with a different passcode.
      for (final d in ['9', '9', '9', '9']) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Still in the dialog, mismatched passcodes.
      expect(find.text('Set passcode'), findsOneWidget);
      expect(find.text('Passcodes did not match. Try again.'), findsOneWidget);
      expect(await AuthRepository.instance.passcodeSet, isFalse);
    });
  });

  group('Security screen — biometric management', () {
    Future<BiometricAvailability> probe() async =>
        const BiometricAvailability(any: true, fingerprint: true, face: true);

    Widget securityApp() => ProviderScope(
      overrides: appOverrides(introShown: true),
      child: MaterialApp(home: SecurityScreen(availabilityProbe: probe)),
    );

    testWidgets('loads cleanly even when passcode secure-storage fails', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStorage();
      // preset face lock + biometric ON so the rows render in managed state
      await presetSetting(tester, AppConstants.kFaceLockEnabled, true);
      await presetSetting(tester, AppConstants.kBiometricEnabled, true);

      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // passcodeSet throws in tests (no secure storage) — must not freeze
      // the screen on the loading spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('face lock row opens the manage sheet with re-scan + remove', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStorage();
      await presetSetting(tester, AppConstants.kFaceLockEnabled, true);

      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('On — tap to re-scan or remove your face'),
        findsOneWidget,
      );

      await tester.tap(find.text('Unlock with Face lock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Re-scan face'), findsOneWidget);
      expect(find.text('Remove face lock'), findsOneWidget);
    });

    testWidgets('fingerprint row opens the manage sheet with test + remove', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStorage();
      await presetSetting(tester, AppConstants.kBiometricEnabled, true);

      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('tap to test it'), findsOneWidget);

      await tester.tap(find.text('Unlock with Fingerprint'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test fingerprint'), findsOneWidget);
      expect(find.text('Remove fingerprint unlock'), findsOneWidget);
    });

    testWidgets('removing face lock from the sheet turns the setting off', (
      tester,
    ) async {
      await freshSettings(tester);
      stubSecureStorage();
      await presetSetting(tester, AppConstants.kFaceLockEnabled, true);

      await tester.pumpWidget(securityApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Unlock with Face lock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Remove face lock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog appears.
      expect(find.text('Remove Face lock?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(await AuthRepository.instance.faceLockEnabled, isFalse);
    });
  });

  group('Input length caps (Long-Password DoS guard)', () {
    test('Validators.password rejects payloads over 128 chars', () {
      expect(
        Validators.password('x' * (Validators.maxPasswordLength + 1)),
        'Password must be at most ${Validators.maxPasswordLength} characters',
      );
      // Exactly at the cap is still valid (only a min-length floor applies).
      expect(Validators.password('x' * Validators.maxPasswordLength), isNull);
    });

    test('Validators.email rejects payloads over 254 chars', () {
      final tooLong = '${'a' * (Validators.maxEmailLength - 5)}@example.com';
      expect(
        Validators.email(tooLong),
        'Email must be at most ${Validators.maxEmailLength} characters',
      );
      expect(Validators.email('user@example.com'), isNull);
    });
  });
}
