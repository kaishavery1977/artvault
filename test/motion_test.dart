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
      for (final t in [
        Duration.zero,
        const Duration(milliseconds: 600),
        const Duration(milliseconds: 1600),
      ]) {
        await tester.pump(t);
        expect(find.text('Hello, Kais Havery'), findsWidgets);
        expect(
          find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
          findsNothing,
        );
      }
    },
  );

  testWidgets('GradientShimmerText renders statically under reduced motion', (
    tester,
  ) async {
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

  group('RevealEntrance', () {
    Opacity gate(WidgetTester tester) => tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(RevealEntrance),
            matching: find.byType(Opacity),
          )
          .first,
    );

    testWidgets('animates in from the delay gate to fully visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RevealEntrance(
              delay: Duration(milliseconds: 200),
              duration: Duration(milliseconds: 400),
              child: Text('cascade item'),
            ),
          ),
        ),
      );

      // Inside the delay the item sits behind the opacity gate…
      await tester.pump();
      expect(gate(tester).opacity, 0);

      // …and after the entrance completes it is fully visible, driven by
      // the animation ticks themselves (no external rebuild required).
      await tester.pump(const Duration(milliseconds: 700));
      expect(gate(tester).opacity, 1);
      expect(find.text('cascade item'), findsOneWidget);
    });

    testWidgets('renders fully visible under reduced motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RevealEntrance(
              reducedMotion: true,
              delay: Duration(milliseconds: 200),
              duration: Duration(milliseconds: 400),
              child: Text('static item'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(gate(tester).opacity, 1);
      expect(find.text('static item'), findsOneWidget);
    });
  });

  testWidgets('staggerReveal children all become visible after their delays', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: staggerReveal(
              [const Text('first'), const Text('second')],
              initialDelay: const Duration(milliseconds: 50),
              interval: const Duration(milliseconds: 90),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);

    // Both cascade gates lift — no content may stay behind an opacity-0
    // gate once the entrance timeline has elapsed.
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      findsNothing,
    );
  });

  testWidgets('ShakeOnError stays quiet on mount and replays per tick', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShakeOnError(tick: 0, child: Text('pin pad'))),
      ),
    );
    await tester.pump();
    // A fresh mount at tick 0 (e.g. the lock screen opening) must not
    // autoplay a shake.
    expect(find.byKey(const ValueKey('shake-0')), findsNothing);
    expect(find.text('pin pad'), findsOneWidget);

    // After a real error tick the shake wrapper mounts.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShakeOnError(tick: 1, child: Text('pin pad'))),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('shake-1')), findsOneWidget);
    // Drain the one-shot shake so the test ends with no active ticker.
    await tester.pump(const Duration(milliseconds: 500));
  });
}
