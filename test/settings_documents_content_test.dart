// Regression tests for the premium content pass on settings + documents:
// the shared IconWell iconography rhythm, the documents loading skeleton,
// the role-aware empty-state action, and hover primitives on document tiles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/widgets/bits.dart';
import 'package:artvault/core/widgets/motion.dart';
import 'package:artvault/data/local/local_database.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/art_document.dart';
import 'package:artvault/features/documents/documents_screen.dart';
import 'package:artvault/features/settings/settings_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

AppUser _user(AppRole role) => AppUser(
  uid: 'u1',
  email: 'u@test.dev',
  displayName: 'Tester',
  role: role,
  plan: AppPlan.free,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);

ArtDocument _doc(String id, String name, {String type = 'Certificate'}) {
  return ArtDocument(
    id: id,
    paintingId: 'p1',
    type: type,
    name: name,
    createdAt: DateTime(2026, 1, 1, 12),
  );
}

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
    await clearTestSettings();
    await clearTestVault();
    await LocalDatabase.instance.clear(AppConstants.boxDocuments);
  });

  setUp(() async {
    await clearTestSettings();
    await clearTestVault();
  });

  Widget wrap(Widget home, {List<Override> extra = const []}) => ProviderScope(
    overrides: [...appOverrides(introShown: true), ...extra],
    child: MaterialApp(home: home),
  );

  group('documents content pass', () {
    testWidgets('loading shows the skeleton, not a false empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DocumentsScreen(),
          extra: [
            documentsProvider.overrideWith(
              (ref) => const Stream<List<ArtDocument>>.empty(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('No documents yet'), findsNothing);
      expect(find.byType(Shimmer), findsWidgets);
    });

    testWidgets('empty roster explains itself to a viewer (no action)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DocumentsScreen(),
          extra: [
            documentsProvider.overrideWith(
              (ref) => Stream.value(const <ArtDocument>[]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Add document'), findsNothing);
    });

    testWidgets('curator gets the Add document entry action on empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DocumentsScreen(),
          extra: [
            authProvider.overrideWith(
              (ref) => FakeAuthController(
                AuthState(
                  status: AuthStatus.authenticated,
                  user: _user(AppRole.curator),
                ),
              ),
            ),
            documentsProvider.overrideWith(
              (ref) => Stream.value(const <ArtDocument>[]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Add document'), findsOneWidget);
    });

    testWidgets('roster tiles carry icon wells and hover lift', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DocumentsScreen(),
          extra: [
            documentsProvider.overrideWith(
              (ref) => Stream.value([
                _doc('d1', 'Provenance cert.pdf', type: 'Certificate'),
                _doc('d2', 'Appraisal 2026.pdf', type: 'Appraisal'),
              ]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Provenance cert.pdf'), findsOneWidget);
      expect(find.text('Appraisal 2026.pdf'), findsOneWidget);
      expect(find.byType(HoverLift), findsNWidgets(2));
      expect(find.byType(IconWell), findsNWidgets(2));
    });
  });

  group('settings content pass', () {
    testWidgets('rows lead with shared icon wells', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Every settings row's icon is an IconWell — same family as documents.
      expect(find.byType(IconWell), findsWidgets);
      // The wrapped icons are still discoverable.
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });
  });
}
