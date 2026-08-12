import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';
import '../gallery/painting_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final paintingsAsync = ref.watch(paintingsProvider);
    final stats = ref.watch(vaultStatsProvider);
    final canEdit = auth.canEdit;

    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();
    final recent = [...paintings]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final showLoading =
        paintingsAsync.isLoading && paintingsAsync.valueOrNull == null;

    return Stack(
      children: [
        // Ambient drifting aurora glow behind the greeting header.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 340,
          child: const IgnorePointer(child: AuroraBackground()),
        ),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(userName: auth.user?.displayName ?? 'Guest'),
            ),
            SliverPadding(
              padding: AppSpacing.screenPadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (showLoading)
                    const _HomeSkeleton()
                  else if (paintings.isEmpty)
                    _WelcomeHero(onUpload: () => context.push('/painting/new'))
                  else ...[
                    _StatsGrid(stats: stats, canEdit: canEdit),
                    const SizedBox(height: AppSpacing.lg),
                    _StorageCard(stats: stats),
                    const SizedBox(height: AppSpacing.lg),
                    _QuickActions(canEdit: canEdit),
                    SectionHeader(
                      title: 'Recent uploads',
                      actionLabel: 'See all',
                      onAction: () => context.go('/gallery'),
                    ),
                  ],
                ]),
              ),
            ),
            if (paintings.isNotEmpty)
              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        PaintingGridCard(painting: recent.take(8).toList()[i]),
                    childCount: recent.take(8).length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppBreakpoints.galleryColumns(context),
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                  ),
                ),
              ),
            SliverPadding(
              padding: AppSpacing.screenPadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (paintings.isNotEmpty) _AiInsights(paintings: paintings),
                  const SizedBox(height: AppSpacing.xl),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shimmer skeleton shown while the vault loads for the first time.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 96)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonBox(height: 96)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 64),
          const SizedBox(height: AppSpacing.lg),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SkeletonBox(width: 92, height: 38),
              SkeletonBox(width: 92, height: 38),
              SkeletonBox(width: 92, height: 38),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 150)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonBox(height: 150)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final String userName;

  const _Header({required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final unread = (ref.watch(notificationsProvider).valueOrNull ?? const [])
        .where((n) => !n.read)
        .length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greeting()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hello, $userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(context, size: 24),
                ),
              ],
            ),
          ),
          _HeaderAction(
            icon: Icons.search,
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _HeaderAction(
            icon: Icons.qr_code_scanner,
            onTap: () => context.push('/scan'),
          ),
          const SizedBox(width: AppSpacing.xs),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _HeaderAction(
                icon: Icons.notifications_outlined,
                onTap: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.07),
      shape: const CircleBorder(),
      child: IconButton(icon: Icon(icon), onPressed: onTap),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  final VoidCallback onUpload;

  const _WelcomeHero({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.palette, size: 44, color: scheme.onPrimary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Welcome to ArtVault',
            style: AppTheme.display(
              context,
              size: 26,
            ).copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your private gallery awaits. Add your first painting and let AI help you catalogue it beautifully.',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onPrimary,
              foregroundColor: scheme.primary,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Upload your first painting'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08);
  }
}

class _StatsGrid extends ConsumerWidget {
  final VaultStats stats;
  final bool canEdit;

  const _StatsGrid({required this.stats, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format with the user's preferred currency, not the hardcoded USD
    // default.
    final currency = ref.watch(currencyProvider);
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
              label: 'Paintings',
              value: '${stats.paintings}',
              countValue: stats.paintings.toDouble(),
              countFormat: (v) => v.round().toString(),
              icon: Icons.brush,
              color: AppColors.secondary,
              onTap: () => context.push('/gallery'),
            ),
            StatCard(
              label: 'Artists',
              value: '${stats.artists}',
              countValue: stats.artists.toDouble(),
              countFormat: (v) => v.round().toString(),
              icon: Icons.person,
              color: AppColors.accent,
              onTap: () => context.push('/artists'),
            ),
            StatCard(
              label: 'Documents',
              value: '${stats.documents}',
              countValue: stats.documents.toDouble(),
              countFormat: (v) => v.round().toString(),
              icon: Icons.description,
              color: AppColors.success,
              onTap: () => context.push('/documents'),
            ),
            StatCard(
              label: 'Collection value',
              value: Formatters.money(
                stats.collectionValue,
                currency: currency,
              ),
              countValue: stats.collectionValue,
              countFormat: (v) => Formatters.money(v, currency: currency),
              icon: Icons.attach_money,
              color: AppColors.info,
            ),
          ],
        );
      },
    );
  }
}

class _StorageCard extends ConsumerWidget {
  final VaultStats stats;

  const _StorageCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final usage = ref.watch(storageUsageProvider).valueOrNull;
    final device = ref.watch(deviceStorageProvider).valueOrNull;
    final total = stats.storageBytes;
    final usedLabel = total > 0 ? Formatters.bytes(total.toInt()) : '0 B';

    // Phone-wide numbers when available, so the user sees how much is left
    // on the device — not just what the vault itself has stored.
    final freeLabel = device != null
        ? Formatters.bytes(device.freeBytes)
        : null;
    final totalDeviceLabel = device != null
        ? Formatters.bytes(device.totalBytes)
        : null;
    final barFraction = device != null
        ? device.usedFraction
        : (usage != null && usage.total > 0
              ? (usage.images + usage.documents) / usage.total
              : 0);

    return GlassCard(
      onTap: () => context.push('/storage'),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Storage used',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                freeLabel ?? usedLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: barFraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: scheme.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            device != null
                ? '$freeLabel free of $totalDeviceLabel phone storage · '
                      'vault uses $usedLabel'
                : 'Images & documents live on-device first, synced to the cloud when connected.',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  final bool canEdit;

  const _QuickActions({required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <(IconData, String, VoidCallback)>[
      if (canEdit)
        (
          Icons.add_photo_alternate,
          'Upload',
          () => context.push('/painting/new'),
        ),
      (Icons.grid_view, 'Gallery', () => context.go('/gallery')),
      (Icons.person, 'Artists', () => context.go('/artists')),
      (Icons.insights, 'Reports', () => context.push('/reports')),
      (
        Icons.favorite,
        'Favorites',
        () => context.push('/gallery', extra: 'favorites'),
      ),
      (Icons.qr_code_scanner, 'Scan', () => context.push('/scan')),
      (Icons.settings_outlined, 'Settings', () => context.go('/settings')),
      if (canEdit) (Icons.sync, 'Sync', () => _sync(context, ref)),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final a in actions)
          _QuickAction(icon: a.$1, label: a.$2, onTap: a.$3),
      ],
    );
  }

  static Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Syncing vault…')));
    final count = await PaintingRepository.instance.syncNow();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count > 0 ? 'Synced $count items.' : 'Vault is up to date.',
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiInsights extends StatelessWidget {
  final List<Painting> paintings;

  const _AiInsights({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final mediumCounts = <String, int>{};
    final artistCounts = <String, int>{};
    var widthSum = 0.0;
    var widthN = 0;
    var heightSum = 0.0;
    var heightN = 0;

    for (final p in paintings) {
      if (p.medium.isNotEmpty) {
        mediumCounts[p.medium] = (mediumCounts[p.medium] ?? 0) + 1;
      }
      if (p.artistName.isNotEmpty) {
        artistCounts[p.artistName] = (artistCounts[p.artistName] ?? 0) + 1;
      }
      if (p.width != null) {
        widthSum += p.width!;
        widthN++;
      }
      if (p.height != null) {
        heightSum += p.height!;
        heightN++;
      }
    }

    final topMedium = _topKey(mediumCounts);
    final topArtist = _topKey(artistCounts);
    final avgW = widthN > 0 ? (widthSum / widthN).toStringAsFixed(1) : '—';
    final avgH = heightN > 0 ? (heightSum / heightN).toStringAsFixed(1) : '—';

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'AI Insights',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InsightRow(
            icon: Icons.palette_outlined,
            label: 'Most common medium',
            value: topMedium ?? '—',
          ),
          _InsightRow(
            icon: Icons.person_outline,
            label: 'Most collected artist',
            value: topArtist ?? '—',
          ),
          _InsightRow(
            icon: Icons.straighten,
            label: 'Average dimensions',
            value: '$avgW × $avgH cm',
          ),
          _InsightRow(
            icon: Icons.auto_graph,
            label: 'Upload trend',
            value: _trend(paintings),
          ),
        ],
      ),
    );
  }

  static String? _topKey(Map<String, int> counts) {
    String? best;
    var bestCount = 0;
    counts.forEach((k, v) {
      if (v > bestCount) {
        best = k;
        bestCount = v;
      }
    });
    return best;
  }

  static String _trend(List<Painting> paintings) {
    final now = DateTime.now();
    final thisMonth = paintings
        .where(
          (p) => p.updatedAt.year == now.year && p.updatedAt.month == now.month,
        )
        .length;
    final lastMonth = now.month == 1
        ? 0
        : paintings
              .where(
                (p) =>
                    p.updatedAt.year == now.year &&
                    p.updatedAt.month == now.month - 1,
              )
              .length;
    if (lastMonth == 0 && thisMonth == 0) return 'No activity yet';
    if (lastMonth == 0) return '$thisMonth added this month';
    final diff = ((thisMonth - lastMonth) / lastMonth * 100).round();
    return '$thisMonth this month (${diff >= 0 ? '+' : ''}$diff% vs last)';
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
