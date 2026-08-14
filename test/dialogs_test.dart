// Widget tests for the Library-location and Rename dialogs, proving the
// TextEditingController-leak fix: each dialog owns its controller in a
// private StatefulWidget and disposes it only when the route fully unmounts
// (after the exit transition). The old pattern created a controller at the
// call site and never disposed it (a leak) — and the passcode dialogs showed
// the harsher variant where early disposal crashed the frame while the
// dialog was still animating out.
//
// The Library-location dialog is driven through its host screen (Settings),
// asserting the value round-trips to the repository. The Rename dialog is
// pumped directly through its public [RenameDocumentDialog] API — a leaf
// dialog that just pops the trimmed name — which keeps the test free of
// Hive/file I/O and makes the dispose invariant the single thing under test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/repositories/settings_repository.dart';
import 'package:artvault/features/documents/documents_screen.dart';
import 'package:artvault/features/settings/settings_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

/// Host that opens [RenameDocumentDialog] on a button press and forwards the
/// popped result (trimmed name on Save, `null` on Cancel).
class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.initial, this.onResult});

  final String initial;
  final ValueChanged<String?>? onResult;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => RenameDocumentDialog(initial: widget.initial),
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
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
    await clearTestSettings();
    await clearTestVault();
    await LocalDatabase.instance.clear(AppConstants.boxDocuments);
  });

  Widget wrap(Widget home, {List<Override> extra = const []}) => ProviderScope(
        overrides: [...appOverrides(introShown: true), ...extra],
        child: MaterialApp(home: home),
      );

  /// Lets the dialog's open transition play out and lands on its content.
  Future<void> settleOpen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Drains the dialog's exit transition far past the point where the old
  /// early-dispose pattern would have thrown.
  Future<void> settleClose(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Library location dialog', () {
    testWidgets('edits the location and closes with no disposed-controller crash',
        (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await settleOpen(tester);

      await tester.tap(find.text('Library location'));
      await settleOpen(tester);

      // Dialog is up with a single editable field.
      expect(find.text('Library location'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Vault Room 2');
      await tester.tap(find.text('Save'));
      await settleClose(tester);

      // Dialog fully gone, value persisted, and — critically — no exception
      // during the exit transition (the leak-fix invariant).
      expect(find.byType(TextField), findsNothing);
      expect(SettingsRepository.instance.libraryLocation, 'Vault Room 2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel closes the dialog cleanly without saving', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await settleOpen(tester);

      await tester.tap(find.text('Library location'));
      await settleOpen(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Should Not Persist');
      await tester.tap(find.text('Cancel'));
      await settleClose(tester);

      expect(find.byType(TextField), findsNothing);
      expect(SettingsRepository.instance.libraryLocation, isNot('Should Not Persist'));
      expect(tester.takeException(), isNull);
    });
  });

  group('Rename document dialog', () {
    testWidgets('Save pops the edited name and survives the exit transition',
        (tester) async {
      String? popped;
      await tester.pumpWidget(wrap(_DialogHost(
        initial: 'Old name.pdf',
        onResult: (r) => popped = r,
      )));

      await tester.tap(find.text('open'));
      await settleOpen(tester);
      expect(find.text('Rename document'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'New name.pdf');
      await tester.tap(find.text('Save'));
      await settleClose(tester);

      expect(popped, 'New name.pdf');
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel pops null and survives the exit transition',
        (tester) async {
      String? popped = 'sentinel';
      await tester.pumpWidget(wrap(_DialogHost(
        initial: 'Keep me.pdf',
        onResult: (r) => popped = r,
      )));

      await tester.tap(find.text('open'));
      await settleOpen(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Changed.pdf');
      await tester.tap(find.text('Cancel'));
      await settleClose(tester);

      expect(popped, isNull);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
