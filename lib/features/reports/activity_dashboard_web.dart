import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/painting.dart';

/// Web activity dashboard — upload trends, medium breakdown, artist stats.
class ActivityDashboardWeb extends ConsumerWidget {
  const ActivityDashboardWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();

    if (paintings.isEmpty) return const SizedBox.shrink();

    // Monthly upload counts (last 12 months)
    final now = DateTime.now();
    final monthlyCounts = <String, int>{};
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = _monthLabel(month);
      monthlyCounts[key] = 0;
    }
    for (final p in paintings) {
      final key = _monthLabel(p.createdAt);
      if (monthlyCounts.containsKey(key)) {
        monthlyCounts[key] = monthlyCounts[key]! + 1;
      }
    }

    // Medium breakdown
    final mediumCounts = <String, int>{};
    for (final p in paintings) {
      if (p.medium.isNotEmpty) {
        mediumCounts[p.medium] = (mediumCounts[p.medium] ?? 0) + 1;
      }
    }

    // Top artists
    final artistCounts = <String, int>{};
    for (final p in paintings) {
      if (p.artistName.isNotEmpty) {
        artistCounts[p.artistName] = (artistCounts[p.artistName] ?? 0) + 1;
      }
    }
    final topArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload trends bar chart
        _DashboardCard(
          title: 'Upload Activity',
          icon: Icons.bar_chart_rounded,
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (monthlyCounts.values.isEmpty
                        ? 1
                        : monthlyCounts.values.reduce(
                            (a, b) => a > b ? a : b,
                          )) *
                    1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final keys = monthlyCounts.keys.toList();
                      return BarTooltipItem(
                        '${keys[group.x.toInt()]}\n${rod.toY.toInt()} paintings',
                        const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final keys = monthlyCounts.keys.toList();
                        final idx = value.toInt();
                        if (idx < 0 || idx >= keys.length)
                          return const SizedBox.shrink();
                        if (idx % 2 != 0) return const SizedBox.shrink();
                        return Text(
                          keys[idx],
                          style: TextStyle(
                            fontSize: 9,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: monthlyCounts.entries.toList().asMap().entries.map((
                  entry,
                ) {
                  final idx = entry.key;
                  final count = entry.value.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: AppColors.accent.withValues(
                          alpha: count > 0 ? 0.8 : 0.15,
                        ),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY:
                              (monthlyCounts.values.isEmpty
                                  ? 1
                                  : monthlyCounts.values.reduce(
                                      (a, b) => a > b ? a : b,
                                    )) *
                              1.2,
                          color: AppColors.accent.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

        const SizedBox(height: 16),

        // Medium breakdown + Top artists side by side
        Row(
          children: [
            Expanded(
              child: _DashboardCard(
                title: 'Mediums',
                icon: Icons.palette_outlined,
                child: Column(
                  children: mediumCounts.entries.take(5).map((e) {
                    final fraction = paintings.isNotEmpty
                        ? e.value / paintings.length
                        : 0.0;
                    final colors = [
                      AppColors.violet500,
                      AppColors.cyan500,
                      AppColors.rose500,
                      AppColors.amber500,
                      AppColors.emerald500,
                    ];
                    final color =
                        colors[mediumCounts.entries.toList().indexOf(e) %
                            colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 8,
                                backgroundColor: color.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${e.value}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DashboardCard(
                title: 'Top Artists',
                icon: Icons.person_outline_rounded,
                child: Column(
                  children: topArtists.take(5).map((e) {
                    final colors = [
                      AppColors.accent,
                      AppColors.cyan400,
                      AppColors.rose400,
                      AppColors.amber400,
                      AppColors.emerald400,
                    ];
                    final color = colors[topArtists.indexOf(e) % colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.3),
                                  color.withValues(alpha: 0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                e.key[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
      ],
    );
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

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
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
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
