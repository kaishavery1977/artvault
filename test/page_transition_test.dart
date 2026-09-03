// Route-transition regression tests for the shared depthPage builder
// (lib/core/widgets/premium/page_transition.dart): every pushed route in the
// app runs through it, so these lock the two behaviors that matter — the 3D
// depth push plays by default, and reduced-motion users get an instant swap
// with no animated gates left behind.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:artvault/core/widgets/premium/page_transition.dart';

Widget _app({required bool reducedMotion}) {
  return MaterialApp.router(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    routerConfig: GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          pageBuilder: (context, _) => depthPage(
            context,
            const Scaffold(body: Center(child: Text('page A'))),
          ),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (context, _) => depthPage(
            context,
            const Scaffold(body: Center(child: Text('page B'))),
          ),
        ),
      ],
    ),
  );
}

Future<void> _pushToB(WidgetTester tester) async {
  final context = tester.element(find.text('page A'));
  GoRouter.of(context).push('/b');
  await tester.pump(); // start the push
}

void main() {
  testWidgets('push plays the depth transition and lands on the new page', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reducedMotion: false));
    await tester.pump();

    expect(find.text('page A'), findsOneWidget);
    expect(find.text('page B'), findsNothing);

    await _pushToB(tester);

    // Mid-flight the incoming page is already building…
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('page B'), findsOneWidget);

    // …and once the 400ms web transition completes, the previous page is gone.
    await tester.pumpAndSettle();
    expect(find.text('page A'), findsNothing);
    expect(find.text('page B'), findsOneWidget);
  });

  testWidgets('reduced motion swaps routes instantly with no animated gates', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reducedMotion: true));
    await tester.pump();

    expect(find.text('page A'), findsOneWidget);

    await _pushToB(tester);

    // Duration.zero: one frame later the swap is complete — the outgoing
    // page is disposed rather than held in a fading/zooming layer.
    await tester.pump();
    expect(find.text('page A'), findsNothing);
    expect(find.text('page B'), findsOneWidget);

    // No opacity-0 entrance gate may linger over the incoming page.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      findsNothing,
    );
  });

  testWidgets('reduced-motion pop also completes without a reverse hold', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reducedMotion: true));
    await tester.pump();

    await _pushToB(tester);
    await tester.pump();
    expect(find.text('page B'), findsOneWidget);

    final context = tester.element(find.text('page B'));
    GoRouter.of(context).pop();
    await tester.pump(); // reverse duration is zero too

    expect(find.text('page B'), findsNothing);
    expect(find.text('page A'), findsOneWidget);
  });
}
