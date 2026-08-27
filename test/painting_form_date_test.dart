// Widget test for the Date created field in the painting form.
//
// After the duplicate-calendar cleanup the field renders exactly ONE
// calendar icon — a highlighted, tappable leading icon (AppTextField's
// `onIconTap`) — and tapping it opens the date picker. The old layout had a
// second decorative left icon plus a duplicate tappable IconButton on the
// right; this test pins the single-icon contract so the duplication can't
// come back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/features/painting/painting_form_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets(
    'Date created renders exactly one tappable calendar icon that opens '
    'the picker',
    (tester) async {
      // Tall surface so the form lays out fully without scroll surprises.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Curated auth (curator) so the form renders its editable content
      // instead of the read-only placeholder; currency pinned to a constant
      // so initState doesn't touch storage.
      final curated = AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(
          uid: 'u1',
          email: 'curator@artvault.test',
          displayName: 'Curator',
          role: AppRole.curator,
          createdAt: DateTime(2024),
          lastLogin: DateTime(2024),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appOverrides(introShown: true),
            currencyProvider.overrideWith((ref) => 'USD'),
            authProvider.overrideWith((ref) => FakeAuthController(curated)),
          ],
          child: const MaterialApp(home: PaintingFormScreen()),
        ),
      );
      await tester.pump();

      // The date field is deep in the form's ListView — scroll it into view.
      await tester.scrollUntilVisible(
        find.byIcon(Icons.calendar_month),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Exactly one calendar icon — the duplicate right-side button is gone.
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);

      // Tapping the icon opens the picker (the highlighted leading icon is the
      // tap target now, not a hidden suffix button).
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('When was this artwork created?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
