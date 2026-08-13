import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/widgets/motion.dart';

void main() {
  testWidgets(
      'GradientShimmerText keeps a visible base in every animation state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GradientShimmerText(
              text: 'Hello, Kais Havery',
              style: const TextStyle(fontSize: 20),
              colors: const [Colors.blue, Colors.purple, Colors.teal],
            ),
          ),
        ),
      ),
    );

    // Mid-flight and after completion the base layer must remain on screen
    // and nothing may sit behind an opacity-0 gate.
    for (final t in [Duration.zero, const Duration(milliseconds: 600), const Duration(milliseconds: 1600)]) {
      await tester.pump(t);
      expect(find.text('Hello, Kais Havery'), findsWidgets);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
        findsNothing,
      );
    }
  });

  testWidgets('GradientShimmerText renders statically under reduced motion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // Override the view's MediaQuery from inside so the widget sees
        // disableAnimations: true.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: GradientShimmerText(
              text: 'ArtVault',
              style: const TextStyle(fontSize: 20),
              colors: const [Colors.blue, Colors.purple],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ArtVault'), findsWidgets);
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      findsNothing,
    );
  });
}
