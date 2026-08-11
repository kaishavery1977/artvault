import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/export_service.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/surfaces.dart';
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
        case _ExportKind.print:
          await ExportService.instance.printCatalog(paintings);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintings =
        (ref.watch(paintingsProvider).valueOrNull ?? const <Painting>[])
            .where((p) => !p.isDeleted)
            .toList();
    final artists = (ref.watch(artistsProvider).valueOrNull ?? const [])
        .where((a) => !a.isDeleted)
        .toList();
    final canSeeAnalytics = ref.watch(authProvider).canSeeAnalytics;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Reports & Analytics',
                style: AppTheme.display(context, size: 28),
              ),
            ),
          ),
          SliverPadding(
            padding: AppSpacing.screenPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SummaryRow(
                  paintings: paintings,
                  artists: artists,
                  currency: ref.watch(currencyProvider),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (canSeeAnalytics) ...[
                  SectionHeader(title: 'Collection breakdown'),
                  _BarCard(
                    title: 'Most common mediums',
                    data: _topMediums(paintings),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BarCard(
                    title: 'Upload trend (last 6 months)',
                    data: _uploadTrend(paintings),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InsightsCard(paintings: paintings),
                ],
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(title: 'Export & print'),
                _ExportCard(
                  onExport: (kind) => _export(context, kind, paintings),
                ),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
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

  const _BarCard({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = data.fold<double>(1, (m, e) => e.$2 > m ? e.$2 : m);

    if (data.isEmpty) {
      return GlassCard(padding: AppSpacing.cardPadding, child: Text(title));
    }

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          entry.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: entry.$2 / max),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Container(
                              height: 16,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.primary.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                              width:
                                  (value * 100).clamp(0, 100) *
                                  MediaQuery.sizeOf(context).width /
                                  100,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 36,
                        child: Text(
                          entry.$2.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
              Icon(Icons.insights, size: 20, color: scheme.primary),
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

enum _ExportKind { pdf, excel, csv, print }

extension _ExportKindX on _ExportKind {
  String get label => switch (this) {
    _ExportKind.pdf => 'PDF catalogue',
    _ExportKind.excel => 'Excel (xlsx)',
    _ExportKind.csv => 'CSV',
    _ExportKind.print => 'Print',
  };

  IconData get icon => switch (this) {
    _ExportKind.pdf => Icons.picture_as_pdf_outlined,
    _ExportKind.excel => Icons.table_chart_outlined,
    _ExportKind.csv => Icons.grid_on_outlined,
    _ExportKind.print => Icons.print_outlined,
  };
}

class _ExportCard extends StatelessWidget {
  final ValueChanged<_ExportKind> onExport;

  const _ExportCard({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          for (final kind in _ExportKind.values)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(kind.icon),
              title: Text(kind.label),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              onTap: () => onExport(kind),
            ),
        ],
      ),
    );
  }
}
