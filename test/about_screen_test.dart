import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/features/settings/about_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

void main() {
  setUpAll(() async {
    disableRuntimeFontFetching();
    await initTestHive();
  });

  Widget wrap() => ProviderScope(
    overrides: [
      ...appOverrides(introShown: true),
      paintingsProvider.overrideWith((ref) => Stream.value(const [])),
      artistsProvider.overrideWith((ref) => Stream.value(const [])),
      documentsProvider.overrideWith((ref) => Stream.value(const [])),
      storageUsageProvider.overrideWith(
        (ref) async => const StorageUsage(
          images: 8 * 1024 * 1024,
          documents: 2 * 1024 * 1024,
        ),
      ),
      settingsBoxProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: const MaterialApp(home: AboutScreen()),
  );

  testWidgets('About screen renders brand, version and sections', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 600));

    // GradientShimmerText paints the wordmark twice (base + sweep layer).
    expect(find.text('ArtVault'), findsWidgets);
    expect(find.text('Your Private Gallery'), findsOneWidget);
    expect(
      find.text(
        'Version ${AppConstants.appVersion} (${AppConstants.appBuild})',
      ),
      findsOneWidget,
    );
    expect(find.text('About'), findsOneWidget);

    // The stats strip now includes the vault-storage tiles.
    expect(find.text('Stored images'), findsOneWidget);
    expect(find.text('Vault size'), findsOneWidget);
    // 8 MB images + 2 MB documents → rendered by Formatters.bytes as 10.0 MB.
    // The count-up takes ~850ms, so pump past it before asserting the value.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('10.0 MB'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    // Scroll down through the remaining sections using ListView dragUntilVisible.
    await tester.dragUntilVisible(
      find.text('Capabilities'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Capabilities'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Support'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Rate ArtVault'), findsOneWidget);
    expect(find.text('Share ArtVault'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Legal'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Kais Havery'), findsWidgets);
    // Drain pending timers without waiting for animations to fully settle
    // (shimmer and aurora run continuously).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
