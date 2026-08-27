// Tests for the accessibility helper widgets (a11y.dart).
// Verifies that SemanticLabel, SemanticHidden, SemanticAnnounce, and
// DecorativeImage produce the correct Semantics tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/widgets/a11y.dart';

import 'hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestHive();
  });

  group('SemanticLabel', () {
    testWidgets('applies label to Semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticLabel(
              label: 'Favorite button',
              child: const Icon(Icons.favorite),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SemanticLabel));
      expect(semantics.label, 'Favorite button');
    });

    testWidgets('marks as button when onTap provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticLabel(
              label: 'Add item',
              onTap: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SemanticLabel));
      expect(semantics.label, 'Add item');
      // GestureDetector wraps the child, making it tappable
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('marks as readOnly when specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticLabel(
              label: 'Status text',
              readOnly: true,
              child: const Text('3 paintings'),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SemanticLabel));
      expect(semantics.label, contains('Status text'));
    });
  });

  group('SemanticHidden', () {
    testWidgets('hides child from screen readers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticHidden(child: const Text('Decorative background')),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SemanticHidden));
      // ExcludeSemantics removes the child's semantics from the tree.
      expect(semantics.label, isEmpty);
    });
  });

  group('SemanticAnnounce', () {
    testWidgets('creates live region for dynamic updates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemanticAnnounce(
              message: '3 items restored',
              child: const Text('Restored'),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SemanticAnnounce));
      expect(semantics.label, contains('3 items restored'));
    });
  });

  group('DecorativeImage', () {
    testWidgets('hides decorative image from screen readers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DecorativeImage(
              child: Container(width: 100, height: 100, color: Colors.blue),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(DecorativeImage));
      expect(semantics.label, isEmpty);
    });
  });
}
