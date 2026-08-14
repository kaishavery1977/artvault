// Tests for the condition-report feature: repository persistence + the
// owning ConditionReportDialog (which must dispose its notes controller only
// when the route unmounts and persist a report on Save).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/models/condition_report.dart';
import 'package:artvault/data/repositories/condition_report_repository.dart';
import 'package:artvault/features/painting/condition_report_dialog.dart';

import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestHive();
    await LocalDatabase.instance
        .clear(AppConstants.boxConditionReports);
  });

  setUp(() async {
    await LocalDatabase.instance.clear(AppConstants.boxConditionReports);
  });

  group('ConditionReportRepository', () {
    test('add → latestFor/forPainting sorted newest-first', () async {
      final repo = ConditionReportRepository.instance;

      await repo.add(
        paintingId: 'p1',
        condition: 'Fair',
        notes: 'Minor scuff on lower right frame.',
        inspectedAt: DateTime(2024, 3, 10),
      );
      await repo.add(
        paintingId: 'p1',
        condition: 'Excellent',
        notes: 'Looks pristine.',
        inspectedAt: DateTime(2025, 6, 1),
      );
      await repo.add(
        paintingId: 'p2',
        condition: 'Good',
        notes: '',
        inspectedAt: DateTime(2025, 1, 15),
      );

      final p1 = repo.forPainting('p1');
      expect(p1, hasLength(2));
      expect(p1.first.condition, 'Excellent'); // newest first
      expect(repo.latestFor('p1')!.notes, 'Looks pristine.');
      expect(repo.latestFor('p2')!.condition, 'Good');
      expect(repo.latestFor('missing'), isNull);
    });

    test('delete soft-deletes and hides the report', () async {
      final repo = ConditionReportRepository.instance;
      final created = await repo.add(
        paintingId: 'p1',
        condition: 'Good',
        notes: 'Routine check.',
        inspectedAt: DateTime(2025, 1, 1),
      );

      expect(repo.forPainting('p1'), hasLength(1));
      await repo.delete(created.id);
      expect(repo.forPainting('p1'), isEmpty);
    });
  });

  group('ConditionReportDialog', () {
    testWidgets('renders chips, notes field, date tile and Save',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (context) =>
                          const ConditionReportDialog(paintingId: 'p1'),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Condition report'), findsOneWidget);
      for (final level in ConditionReport.levels) {
        expect(find.text(level), findsOneWidget);
      }
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Inspection date'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save report'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('Save pops with the entered draft (no I/O in the dialog)',
        (tester) async {
      ConditionReportDraft? popped;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<ConditionReportDraft>(
                      context: context,
                      builder: (context) =>
                          const ConditionReportDialog(paintingId: 'p1'),
                    ).then((d) => popped = d),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Crack in the varnish near the signature.',
      );
      await tester.tap(find.text('Fair')); // switch the condition chip
      await tester.pump();
      await tester.tap(find.text('Save report'));
      await tester.pumpAndSettle();

      // Dialog popped with a complete draft.
      expect(find.text('Condition report'), findsNothing);
      expect(popped, isNotNull);
      expect(popped!.condition, 'Fair');
      expect(popped!.notes, 'Crack in the varnish near the signature.');
      expect(popped!.photo, isNull);
    });
  });
}
