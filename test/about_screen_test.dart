import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        ],
        child: const MaterialApp(home: AboutScreen()),
      );

  testWidgets('About screen renders brand, version and sections', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 600));

    // GradientShimmerText paints the wordmark twice (base + sweep layer).
    expect(find.text('ArtVault'), findsWidgets);
    expect(find.text('Your Private Gallery'), findsOneWidget);
    expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // The stats strip now includes the vault-storage tiles.
    expect(find.text('Stored images'), findsOneWidget);
    expect(find.text('Vault size'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    // The stats card's GridView is also a Scrollable, so target the page's
    // ListView explicitly when scrolling through the lazy sections.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Capabilities'), 200, scrollable: list);
    expect(find.text('Capabilities'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Celebrations'), 200, scrollable: list);
    expect(find.text('Celebrations'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Support'), 200, scrollable: list);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Rate ArtVault'), findsOneWidget);
    expect(find.text('Share ArtVault'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Legal'), 200, scrollable: list);
    expect(find.text('Legal'), findsOneWidget);
    // The credit's footer line is a plain Text — scroll to it, then assert
    // the shimmer credit (which paints two layers) is on screen too.
    await tester.scrollUntilVisible(
      find.text('Every masterpiece starts with a single brushstroke.'),
      200,
      scrollable: list,
    );
    expect(find.text('Built by Kais Havery'), findsWidgets);
  });
}
