import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/painting.dart';

/// Collection valuation line chart — shows portfolio value over time.
class CollectionValuationChart extends ConsumerWidget {
  const CollectionValuationChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();

    if (paintings.isEmpty) return const SizedBox.shrink();

    // Build monthly cumulative value data
    final now = DateTime.now();
    final monthlyData = <DateTime, double>{};

    // Sort paintings by date
    final sorted = List<Painting>.from(paintings)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    double cumulative = 0;
    for (final p in sorted) {
      cumulative += p.price ?? 0;
      final monthKey = DateTime(p.createdAt.year, p.createdAt.month);
      monthlyData[monthKey] = cumulative;
    }

    // Fill in months with no new paintings (carry forward last value)
    if (monthlyData.isNotEmpty) {
      final first = monthlyData.keys.first;
      final last = DateTime(now.year, now.month);
      var current = DateTime(first.year, first.month + 1);
      double lastValue = monthlyData[first] ?? 0;
      while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
        monthlyData.putIfAbsent(current, () => lastValue);
        lastValue = monthlyData[current]!;
        current = DateTime(current.year, current.month + 1);
      }
    }

    final entries = monthlyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    final labels = <String>[];

    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
      labels.add(_monthLabel(entries[i].key));
    }

    final maxValue = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final currency = ref.watch(currencyProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppColors.emerald500,
              ),
              const SizedBox(width: 8),
              Text(
                'Portfolio Value',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                Formatters.money(maxValue, currency: currency),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emerald500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'Add more paintings to see value trend',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxValue > 0 ? maxValue / 4 : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                          strokeWidth: 0.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                Formatters.money(value, currency: currency),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              // Show every other label
                              if (idx % 2 != 0 && labels.length > 6) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                labels[idx],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.emerald500,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: spots.length < 12,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: AppColors.emerald500,
                                strokeColor: Colors.white,
                                strokeWidth: 1.5,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.emerald500.withValues(alpha: 0.2),
                                AppColors.emerald500.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final idx = spot.x.toInt();
                              final label = idx >= 0 && idx < labels.length
                                  ? labels[idx]
                                  : '';
                              return LineTooltipItem(
                                '$label\n${Formatters.money(spot.y, currency: currency)}',
                                TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.03);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year.toString().substring(2)}';
  }
}
