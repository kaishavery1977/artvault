// Widget tests for the change-password and reset-password dialogs, locking
// in the owning-TextEditingController pattern (controllers disposed only
// when the route fully unmounts, after the exit transition). The dialogs are
// pumped directly through their public APIs — no Hive, no Firebase — so the
// dispose invariant and the validation contract are the only things under
// test. The change dialog's valid-submit path is deliberately not exercised:
// it calls AuthRepository → Firebase, which is unavailable in tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/features/settings/security_screen.dart';

import 'helpers.dart';

/// Host that opens [ChangePasswordDialog] on a button press and forwards the
/// popped result (`true` on success, `false` on Cancel).
class _ChangePasswordHost extends StatefulWidget {
  const _ChangePasswordHost({this.onResult});

  final ValueChanged<bool?>? onResult;

  @override
  State<_ChangePasswordHost> createState() => _ChangePasswordHostState();
}

class _ChangePasswordHostState extends State<_ChangePasswordHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => const ChangePasswordDialog(),
              );
              widget.onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

/// Host that opens [ResetPasswordDialog] on a button press and forwards the
/// popped email (trimmed on Send, `null` on Cancel).
class _ResetPasswordHost extends StatefulWidget {
  const _ResetPasswordHost({this.initial = '', this.onResult});

  final String initial;
  final ValueChanged<String?>? onResult;

  @override
  State<_ResetPasswordHost> createState() => _ResetPasswordHostState();
}

class _ResetPasswordHostState extends State<_ResetPasswordHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => ResetPasswordDialog(initial: widget.initial),
              );
              widget.onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  /// Lets the dialog's open transition play out.
  Future<void> settleOpen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Drains the exit transition far past where the old early-dispose pattern
  /// would have thrown.
  Future<void> settleClose(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder field(int index) => find.byType(TextField).at(index);

  group('ChangePasswordDialog', () {
    testWidgets('rejects empty fields inline and stays open', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ChangePasswordHost()));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      expect(find.byType(TextField), findsNWidgets(3));

      await tester.tap(find.text('Update password'));
      await tester.pump();

      expect(find.text('Fill in all three fields'), findsOneWidget);
      // Still open — the dialog did not pop on a validation error.
      expect(find.byType(TextField), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects a password shorter than 6 characters', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ChangePasswordHost()));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      await tester.enterText(field(0), 'old-pass');
      await tester.enterText(field(1), '12345');
      await tester.enterText(field(2), '12345');
      await tester.tap(find.text('Update password'));
      await tester.pump();

      expect(
        find.text('New password must be at least 6 characters'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects mismatched new passwords', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ChangePasswordHost()));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      await tester.enterText(field(0), 'old-pass');
      await tester.enterText(field(1), 'new-pass-1');
      await tester.enterText(field(2), 'new-pass-2');
      await tester.tap(find.text('Update password'));
      await tester.pump();

      expect(find.text('New passwords do not match'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel pops false and survives the exit transition',
        (tester) async {
      bool? popped;
      await tester.pumpWidget(MaterialApp(
        home: _ChangePasswordHost(onResult: (r) => popped = r),
      ));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      await tester.tap(find.text('Cancel'));
      await settleClose(tester);

      expect(popped, isFalse);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ResetPasswordDialog', () {
    testWidgets('Send pops the trimmed email and survives the exit transition',
        (tester) async {
      String? popped;
      await tester.pumpWidget(MaterialApp(
        home: _ResetPasswordHost(
          initial: 'old@test.dev',
          onResult: (r) => popped = r,
        ),
      ));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      // Pre-filled with the passed-in email.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'old@test.dev',
      );

      await tester.enterText(find.byType(TextField), '  new@test.dev  ');
      await tester.tap(find.text('Send reset link'));
      await settleClose(tester);

      expect(popped, 'new@test.dev');
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel pops null and survives the exit transition',
        (tester) async {
      String? popped = 'sentinel';
      await tester.pumpWidget(MaterialApp(
        home: _ResetPasswordHost(
          initial: 'old@test.dev',
          onResult: (r) => popped = r,
        ),
      ));
      await tester.tap(find.text('open'));
      await settleOpen(tester);

      await tester.tap(find.text('Cancel'));
      await settleClose(tester);

      expect(popped, isNull);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
