// Regression tests for the lightweight L10n layer: English stays the
// source of truth (null/no-scope contexts render English), Hindi strings
// translate through the active scope, and untranslated keys fall back to
// English instead of blanking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/l10n/app_strings.dart';

void main() {
  test('null context renders the English source text', () {
    expect(L10n.t(null, 'Settings'), 'Settings');
    expect(L10n.t(null, 'Something untranslated'), 'Something untranslated');
  });

  testWidgets('an English scope passes text through unchanged', (tester) async {
    late BuildContext probe;
    await tester.pumpWidget(
      L10n(
        languageCode: 'en',
        child: Builder(
          builder: (context) {
            probe = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(L10n.t(probe, 'Gallery'), 'Gallery');
    expect(L10n.t(probe, 'Notifications'), 'Notifications');
  });

  testWidgets('a Hindi scope translates known keys and falls back otherwise', (
    tester,
  ) async {
    late BuildContext probe;
    await tester.pumpWidget(
      L10n(
        languageCode: 'hi',
        child: Builder(
          builder: (context) {
            probe = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(L10n.t(probe, 'Settings'), 'सेटिंग्स');
    expect(L10n.t(probe, 'Artists'), 'कलाकार');
    expect(L10n.t(probe, 'Curator'), 'क्यूरेटर');
    expect(L10n.t(probe, 'paintings'), 'पेंटिंग्स');
    // Keys that have not been translated yet stay English.
    expect(
      L10n.t(probe, 'Not yet translated anywhere'),
      'Not yet translated anywhere',
    );
  });
}
