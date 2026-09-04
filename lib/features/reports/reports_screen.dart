import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'collection_valuation_chart.dart';
import 'activity_dashboard_web.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/export_service.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/web/content_column.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';

/// Collection analytics + report generation.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    _ExportKind kind,
    List<Painting> paintings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Preparing ${kind.label.toLowerCase()}…')),
    );
    try {
      switch (kind) {
        case _ExportKind.pdf:
          final pdf = await ExportService.instance.buildCatalogPdf(paintings);
          await ShareService.instance.sharePdf(pdf, 'artvault_catalog.pdf');
        case _ExportKind.excel:
          final file = await ExportService.instance.exportExcel(paintings);
          await ShareService.instance.shareFile(
            file.path,
            text: 'Collection export',
          );
        case _ExportKind.csv:
          final file = await ExportService.instance.exportCsv(paintings);
          await ShareService.instance.shareFile(file.path, text: 'CSV export');
        case _ExportKind.insurance:
          final pdf = await ExportService.instance.buildInsuranceSchedulePdf(
            paintings,
          );
          await ShareService.instance.sharePdf(pdf, 'insurance_schedule.pdf');
        case _ExportKind.qrLabels:
          final pdf = await ExportService.instance.buildQrLabelSheetPdf(
            paintings,
          );
          await ShareService.instance.sharePdf(pdf, 'qr_labels.pdf');
        case _ExportKind.print:
          await ExportService.instance.printCatalog(paintings);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final rawPaintings = paintingsAsync.valueOrNull ?? const <Painting>[];
    // First paint only: while the vault is still loading, show shimmer
    // skeletons — never a false zeroed summary or an empty-state flash.
    final loading =
        paintingsAsync.isLoading && paintingsAsync.valueOrNull == null;
    final paintings = rawPaintings.where((p) => !p.isDeleted).toList();
    final artists = (ref.watch(artistsProvider).valueOrNull ?? const [])
        .where((a) => !a.isDeleted)
        .toList();
    final flags = ref.watch(
      authProvider.select(
        (a) => (canSeeAnalytics: a.canSeeAnalytics, canEdit: a.canEdit),
      ),
    );

    final List<Widget> content;
    if (loading) {
      content = const [_ReportsSkeleton()];
    } else if (paintings.isEmpty) {
      // Empty vault: the one state that matters is the add action — the
      // summary, charts and export card are all meaningless at zero, so the
      // empty state owns the single CTA (mirrors the #33 FAB dedupe).
      content = [
        EmptyState(
          icon: Icons.query_stats_rounded,
          title: 'No collection data yet',
          subtitle:
              'Portfolio value trends, medium breakdowns and exports appear '
              'here once your vault holds artwork.',
          actionLabel: flags.canEdit ? 'Add your first painting' : null,
          onAction: flags.canEdit ? () => context.push('/painting/new') : null,
        ),
      ];
    } else {
      content = staggerReveal([
        _SummaryRow(
          paintings: paintings,
          artists: artists,
          currency: ref.watch(currencyProvider),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Web-only: enhanced charts and dashboard
        if (kIsWeb && flags.canSeeAnalytics) ...[
          const CollectionValuationChart(),
          const SizedBox(height: AppSpacing.lg),
          const ActivityDashboardWeb(),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (flags.canSeeAnalytics) ...[
          // On web the activity dashboard already covers uploads and
          // mediums, so the bar-chart breakdown stays on the phone layout
          // only — no duplicated charts in the reading column.
          if (!kIsWeb) ...[
            SectionHeader(title: 'Collection breakdown'),
            _BarCard(
              title: 'Most common mediums',
              data: _topMediums(paintings),
              icon: Icons.palette_outlined,
              iconColor: AppColors.violet500,
            ),
            const SizedBox(height: AppSpacing.md),
            _BarCard(
              title: 'Upload trend (last 6 months)',
              data: _uploadTrend(paintings),
              icon: Icons.schedule_rounded,
              iconColor: AppColors.cyan500,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _InsightsCard(paintings: paintings),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Export & print'),
        _ExportCard(onExport: (kind) => _export(context, kind, paintings)),
        const SizedBox(height: AppSpacing.xl),
      ], context: context);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: kIsWeb
                // The web shell's top bar already names this page — keep
                // only a little breathing room under it.
                ? const SizedBox(height: AppSpacing.xs)
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.adaptiveSpace(AppSpacing.md),
                      AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
                      context.adaptiveSpace(AppSpacing.md),
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Reports & Analytics',
                      style: AppTheme.display(
                        context,
                        size: context.adaptiveFont(28),
                      ),
                    ),
                  ),
          ),
          SliverPadding(
            padding: AppSpacing.screenPadding,
            sliver: kIsWeb
                // On web, reports cards sit in a centered reading column so
                // charts don't stretch across the whole desktop viewport.
                ? SliverToBoxAdapter(
                    child: WebContentColumn(
                      maxWidth: 1120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: content,
                      ),
                    ),
                  )
                : SliverList(delegate: SliverChildListDelegate(content)),
          ),
        ],
      ),
    );
  }

  static List<(String, double)> _topMediums(List<Painting> paintings) {
    final counts = <String, int>{};
    for (final p in paintings) {
      if (p.medium.isNotEmpty) {
        counts[p.medium] = (counts[p.medium] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).map((e) => (e.key, e.value.toDouble())).toList();
  }

  static List<(String, double)> _uploadTrend(List<Painting> paintings) {
    final now = DateTime.now();
    final result = <(String, double)>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final count = paintings
          .where(
            (p) =>
                p.createdAt.year == month.year &&
                p.createdAt.month == month.month,
          )
          .length;
      result.add((DateFormat('MMM').format(month), count.toDouble()));
    }
    return result;
  }
}

/// Shimmer skeleton shown while the vault first loads — mirrors the
/// documents/artists loading language so reports never flashes a false
/// zeroed summary or a premature empty state.
class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat-row placeholders (4 up on wide layouts, 2×2 on narrow).
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 132,
                children: [
                  for (var i = 0; i < 4; i++)
                    const SkeletonBox(
                      height: 132,
                      radius: AppSpacing.radiusCard,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: 264, radius: AppSpacing.radiusCard),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: 210, radius: AppSpacing.radiusCard),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: 210, radius: AppSpacing.radiusCard),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<Painting> paintings;
  final List<dynamic> artists;
  final String currency;

  const _SummaryRow({
    required this.paintings,
    required this.artists,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final value = paintings.fold<double>(0, (s, p) => s + (p.price ?? 0));
    final avgW =
        paintings
            .where((p) => p.width != null)
            .fold<double>(0, (s, p) => s + p.width!) /
        (paintings.where((p) => p.width != null).length.clamp(1, 1 << 31));
    final avgH =
        paintings
            .where((p) => p.height != null)
            .fold<double>(0, (s, p) => s + p.height!) /
        (paintings.where((p) => p.height != null).length.clamp(1, 1 << 31));

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          // Fixed cell height (not aspect ratio): on narrow screens an
          // aspect-ratio cell gets too short for the card content and
          // overflows. 132dp = 32dp card padding + 96dp content + slack.
          mainAxisExtent: 132,
          children: [
            StatCard(
              label: 'Total value',
              value: Formatters.money(value, currency: currency),
              icon: Icons.account_balance_wallet,
              color: AppColors.info,
            ),
            StatCard(
              label: 'Artworks',
              value: '${paintings.length}',
              icon: Icons.brush,
              color: AppColors.secondary,
            ),
            StatCard(
              label: 'Artists',
              value: '${artists.length}',
              icon: Icons.person,
              color: AppColors.accent,
            ),
            StatCard(
              label: 'Avg. size',
              value: avgW == 0
                  ? '—'
                  : '${avgW.toStringAsFixed(0)}×${avgH.toStringAsFixed(0)}',
              icon: Icons.straighten,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _BarCard extends StatelessWidget {
  final String title;
  final List<(String, double)> data;
  final IconData icon;
  final Color iconColor;

  const _BarCard({
    required this.title,
    required this.data,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return GlassCard(
        padding: AppSpacing.cardPadding,
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    final maxVal = data.fold<double>(1, (m, e) => e.$2 > m ? e.$2 : m);
    final barColors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
    ];

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(icon: icon, color: iconColor, size: 32, iconSize: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${data[groupIndex].$1}\n',
                        TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: rod.toY.toStringAsFixed(0),
                            style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.onSurface.withValues(alpha: 0.07),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
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
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            data[idx].$1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].$2,
                          color: barColors[i % barColors.length],
                          width: data.length > 8 ? 14 : 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxVal * 1.2,
                            color: scheme.onSurface.withValues(alpha: 0.04),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Reduced motion swaps bars instantly — no grow animation.
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<Painting> paintings;

  const _InsightsCard({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artists = <String, int>{};
    for (final p in paintings) {
      if (p.artistName.isNotEmpty) {
        artists[p.artistName] = (artists[p.artistName] ?? 0) + 1;
      }
    }
    final topArtist = artists.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = topArtist.isEmpty ? null : topArtist.first.key;

    final favorites = paintings.where((p) => p.isFavorite).length;
    final valued = paintings
        .where((p) => p.price != null && p.price! > 0)
        .length;

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                icon: Icons.insights,
                color: scheme.primary,
                size: 32,
                iconSize: 17,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'AI Collection Analytics',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Row('Most collected artist', best ?? '—'),
          _Row('Favorites', '$favorites of ${paintings.length}'),
          _Row(
            'With appraised value',
            '${(paintings.isEmpty ? 0 : (valued / paintings.length * 100).round())}%',
          ),
          _Row('Favourite medium', _favouriteMedium(paintings)),
        ],
      ),
    );
  }

  static String _favouriteMedium(List<Painting> paintings) {
    final counts = <String, int>{};
    for (final p in paintings) {
      if (p.medium.isNotEmpty) counts[p.medium] = (counts[p.medium] ?? 0) + 1;
    }
    if (counts.isEmpty) return '—';
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

enum _ExportKind { pdf, excel, csv, insurance, qrLabels, print }

extension _ExportKindX on _ExportKind {
  String get label => switch (this) {
    _ExportKind.pdf => 'PDF catalogue',
    _ExportKind.excel => 'Excel (xlsx)',
    _ExportKind.csv => 'CSV',
    _ExportKind.insurance => 'Insurance schedule (PDF)',
    _ExportKind.qrLabels => 'QR inventory labels (PDF)',
    _ExportKind.print => 'Print',
  };

  IconData get icon => switch (this) {
    _ExportKind.pdf => Icons.picture_as_pdf_outlined,
    _ExportKind.excel => Icons.table_chart_outlined,
    _ExportKind.csv => Icons.grid_on_outlined,
    _ExportKind.insurance => Icons.verified_user_outlined,
    _ExportKind.qrLabels => Icons.qr_code_2_outlined,
    _ExportKind.print => Icons.print_outlined,
  };

  /// Hue for the leading icon well — the six export actions read as one
  /// family with distinct accents (same rhythm as document tiles).
  Color get color => switch (this) {
    _ExportKind.pdf => AppColors.violet500,
    _ExportKind.excel => AppColors.success,
    _ExportKind.csv => AppColors.info,
    _ExportKind.insurance => AppColors.accent,
    _ExportKind.qrLabels => AppColors.secondary,
    _ExportKind.print => AppColors.amber500,
  };
}

class _ExportCard extends StatelessWidget {
  final ValueChanged<_ExportKind> onExport;

  const _ExportCard({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: AppSpacing.cardPadding,
      // Material ancestor so the export rows get ink ripples + hover
      // washes. Grouped rows keep native hover — lift stays reserved for
      // standalone tiles, per the settings/documents pass.
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (final kind in _ExportKind.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                hoverColor: kind.color.withValues(alpha: 0.05),
                leading: IconWell(
                  icon: kind.icon,
                  color: kind.color,
                  size: 36,
                  iconSize: 18,
                ),
                title: Text(kind.label),
                trailing: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => onExport(kind),
              ),
          ],
        ),
      ),
    );
  }
}
