// Widget-level guard for the Long-Password DoS fix: the login email/password
// fields cap oversized input at the input layer (enforced
// LengthLimitingTextInputFormatter), so a multi-thousand-character payload can
// never reach the auth backend or a hasher.
//
// Kept in its own file (fresh test isolate) — it uses text input after heavy
// Hive/secure-storage widget tests, which hangs when shareable-binding state
// is reused inside auth_flows_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/theme/adaptive_layout.dart';
import 'package:artvault/core/utils/validators.dart';
import 'package:artvault/features/auth/login_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

Future<void> _drainLoginMotion(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  Future<void> freshSettings(WidgetTester tester) =>
      tester.runAsync(clearTestSettings);

  String fieldText(WidgetTester tester, int index) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(index),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  testWidgets('login password field truncates a 300-char paste to 128', (
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

    await tester.enterText(find.byType(TextFormField).at(1), 'x' * 300);
    expect(fieldText(tester, 1).length, Validators.maxPasswordLength);
  });

  testWidgets('login email field truncates an oversized paste to 254', (
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

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '${'a' * 300}@example.com',
    );
    expect(fieldText(tester, 0).length, Validators.maxEmailLength);
  });
}
