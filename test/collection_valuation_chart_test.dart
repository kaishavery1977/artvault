// Regression tests for the Portfolio Value chart x-axis.
//
// The fractional-tick bug: fl_chart emitted x-ticks at 0, 0.5, 1, 1.5, …
// for small datasets, and the label callback's value.toInt() mapped several
// ticks onto the same month — vaults with a handful of months showed each
// label ("May 26") repeated and overlapping. The fix pins minX/maxX to the
// data range and bottom-title interval to 1, so each month gets exactly one
// integer tick.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/reports/collection_valuation_chart.dart';

import 'helpers.dart';

Painting _paint(String id, DateTime created, {double? price}) => Painting(
  id: id,
  title: 'Art $id',
  artistId: 'a-$id',
  artistName: 'Artist',
  price: price ?? 1000,
  createdAt: created,
  updatedAt: created,
);

Widget _chartApp(List<Painting> paintings) {
  return ProviderScope(
    overrides: [
      paintingsProvider.overrideWith((ref) => Stream.value(paintings)),
      currencyProvider.overrideWith((ref) => 'USD'),
    ],
    child: const MaterialApp(home: Scaffold(body: CollectionValuationChart())),
  );
}

Future<void> _pump(WidgetTester tester, List<Painting> paintings) async {
  await tester.pumpWidget(_chartApp(paintings));
  await tester.pump(); // deliver the stream
  // Drain the entrance animation (fade + slide, ~600ms).
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data;

  testWidgets('five months produce one integer x-tick per month', (
    tester,
  ) async {
    final paintings = [
      for (var m = 5; m <= 9; m++)
        _paint('p$m', DateTime(2026, m, 15), price: 1000.0 * m),
    ];
    await _pump(tester, paintings);

    expect(find.byType(LineChart), findsOneWidget);

    final data = chartData(tester);
    // The whole bug: fractional ticks (0, 0.5, 1…) collapsed onto the same
    // month label. Explicit bounds + interval 1 = one tick per point.
    expect(data.minX, 0);
    expect(data.maxX, 4);
    expect(data.titlesData.bottomTitles.sideTitles.interval, 1);
  });

  testWidgets('a long history stays at one tick per month, no fractional '
      'thinning change', (tester) async {
    final now = DateTime.now();
    final first = DateTime(2025, 1);
    final paintings = [
      for (var m = 1; m <= 14; m++)
        _paint('p$m', DateTime(2025, m, 10), price: 500.0 * m),
    ];
    await _pump(tester, paintings);

    final data = chartData(tester);
    expect(data.minX, 0);
    // Every month between the first painting and today gets a carry-forward
    // entry — assert the axis spans exactly that fill, still integer ticks.
    final fillMonths =
        (now.year - first.year) * 12 + (now.month - first.month) + 1;
    expect(data.maxX, (fillMonths - 1).toDouble());
    expect(data.titlesData.bottomTitles.sideTitles.interval, 1);
  });

  testWidgets('a single painting shows the trend hint, not a broken chart', (
    tester,
  ) async {
    final now = DateTime.now();
    // Same month as today: the carry-forward fill adds nothing, so there is
    // exactly one spot and the hint (not a line chart) should render.
    await _pump(tester, [_paint('p1', DateTime(now.year, now.month, 1))]);

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Add more paintings to see value trend'), findsOneWidget);
  });
}
