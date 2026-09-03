import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'home_screen_web.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/adaptive_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/premium/premium.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';
import '../../data/remote/cloud_backend.dart';
import '../../core/widgets/a11y.dart';
import '../gallery/painting_card.dart';
import '../settings/repair_images_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const HomeScreenWeb();

    final auth = ref.watch(authProvider);
    final paintingsAsync = ref.watch(paintingsProvider);
    final canEdit = auth.canEdit;

    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();
    final recent = [...paintings]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final missingImages = paintings
        .where(RepairImagesScreen.needsRepair)
        .length;
    final restore = ref.watch(restoreProgressProvider);
    final showRestore =
        restore != null && (restore.running || restore.itemsRestored > 0);
    final failedUploads = ref.watch(cloudSyncHealthProvider);
    // A successful sync (streak back to 0) un-dismisses the hint so it can
    // return if failures start accumulating again — dismissal is per-issue,
    // not permanent.
    ref.listen(cloudSyncHealthProvider, (prev, next) {
      if (next == 0 && (prev ?? 0) > 0) {
        ref.read(cloudSyncHintDismissedProvider.notifier).state = false;
      }
    });
    final hintDismissed = ref.watch(cloudSyncHintDismissedProvider);
    final showCloudHint =
        failedUploads >= CloudBackend.uploadFailureHintAfter && !hintDismissed;
    final showLoading =
        paintingsAsync.isLoading && paintingsAsync.valueOrNull == null;

    // Adapt the aurora background height and screen padding.
    // In landscape, shrink the aurora since there's less vertical space.
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final auroraHeight = context.scaled(isLandscape ? 200 : 340);
    final screenPad = context.scaledPadding(AppSpacing.screenPadding);

    return Stack(
      children: [
        // Ambient drifting aurora glow behind the greeting header.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: auroraHeight,
          child: const SemanticHidden(
            child: IgnorePointer(child: AuroraBackground()),
          ),
        ),
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paintingsProvider);
            ref.invalidate(vaultStatsProvider);
            ref.invalidate(artistsProvider);
            ref.invalidate(documentsProvider);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(userName: auth.user?.displayName ?? 'Guest'),
              ),
              SliverPadding(
                padding: screenPad,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    staggerReveal(
                      [
                        if (showRestore) ...[
                          _RestoreBanner(progress: restore),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (showCloudHint) ...[
                          const _CloudSyncUnavailableHint(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (showLoading)
                          const _HomeSkeleton()
                        else if (paintings.isEmpty)
                          _WelcomeHero(
                            canEdit: canEdit,
                            onUpload: () => context.push('/painting/new'),
                          )
                        else ...[
                          if (missingImages > 0) ...[
                            _MissingImagesBanner(
                              count: missingImages,
                              onTap: () => context.push('/repair-images'),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          const _CollectionHero(),
                          const SizedBox(height: AppSpacing.lg),
                          _QuickActions(canEdit: canEdit),
                          const SizedBox(height: AppSpacing.lg),
                          if (paintings.isNotEmpty)
                            _AiInsights(paintings: paintings),
                          SectionHeader(
                            title: 'Recent uploads',
                            actionLabel: 'See all',
                            onAction: () => context.go('/gallery'),
                          ),
                        ],
                      ],
                      initialDelay: const Duration(milliseconds: 80),
                      interval: const Duration(milliseconds: 90),
                      context: context,
                    ),
                  ),
                ),
              ),
              if (paintings.isNotEmpty)
                SliverPadding(
                  padding: AppSpacing.screenPadding,
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => PaintingGridCard(
                        painting: recent.take(8).toList()[i],
                      ),
                      childCount: recent.take(8).length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: AppBreakpoints.galleryColumns(context),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
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

/// Warning banner shown when one or more artworks lost their image files
/// (e.g. after a reinstall wiped the vault). One tap jumps to Repair images.
/// Live banner for the restore-from-cloud pipeline: a spinner + stage label
/// while it runs, a dismissible summary once it finishes with files
/// re-downloaded. Hidden entirely when nothing was restored.
class _RestoreBanner extends ConsumerWidget {
  final RestoreProgress progress;

  const _RestoreBanner({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final done = !progress.running;
    final accent = done ? const Color(0xFF34A853) : scheme.primary;
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (done)
              Icon(Icons.check_circle_outline, color: accent)
            else
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done
                        ? 'Restored ${progress.itemsRestored} '
                              '${progress.itemsRestored == 1 ? 'file' : 'files'} '
                              'from the cloud'
                        : progress.stage,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Re-downloading your vault — keep the app open',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (done)
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () =>
                    ref.read(restoreProgressProvider.notifier).state = null,
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact "cloud sync unavailable" chip: shown after several consecutive
/// upload failures (not on a rare blip), dismissible, and deliberately muted
/// — the app keeps working fully offline, so this is information, not an
/// alarm. Tapping the row retries the sync once; the ✕ hides it for the
/// session.
class _CloudSyncUnavailableHint extends ConsumerWidget {
  const _CloudSyncUnavailableHint();

  Future<void> _retry(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Retrying cloud sync…')),
    );
    await PaintingRepository.instance.syncNow();
    final streak = CloudBackend.instance.failedUploadStreak.value;
    final lastError = CloudBackend.instance.lastUploadError.value;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          streak > 0
              ? lastError.isNotEmpty
                    ? lastError
                    : 'Still can’t reach the cloud — changes stay on this device.'
              : 'Cloud sync is working again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.65);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: () => _retry(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: CloudBackend.instance.lastUploadError,
                  builder: (_, error, _) => Text(
                    error.isNotEmpty
                        ? error
                        : 'Cloud sync unavailable \u2014 tap to retry',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(cloudSyncHintDismissedProvider.notifier).state =
                        true,
                icon: const Icon(Icons.close, size: 14),
                color: muted,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingImagesBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MissingImagesBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.broken_image_outlined, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 artwork needs its image back'
                          : '$count artworks need their images back',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to re-pick from your gallery',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
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

    // Adapt header padding based on device resolution.
    final topPad = AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4;
    final hPad = context.adaptiveSpace(AppSpacing.md);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greeting()}',
                  style: TextStyle(
                    fontSize: context.adaptiveFont(13),
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                GradientShimmerText(
                  text: 'Hello, $userName',
                  style: AppTheme.display(
                    context,
                    size: context.adaptiveFont(24),
                  ),
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                  duration: const Duration(milliseconds: 1200),
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
      child: IconButton(
        icon: Icon(icon),
        onPressed: onTap,
        tooltip: icon == Icons.search
            ? 'Search'
            : icon == Icons.qr_code_scanner
            ? 'Scan QR code'
            : null,
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onUpload;

  const _WelcomeHero({required this.canEdit, required this.onUpload});

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
              if (canEdit)
                FilledButton.icon(
                  onPressed: onUpload,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onPrimary,
                    foregroundColor: scheme.primary,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Upload your first painting'),
                )
              else
                Text(
                  'This vault is read-only for your account.',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        )
        // A single soft light sweep across the hero once it has landed — a
        // spotlight pass that makes the empty vault feel curated. The fade
        // + slide entrance completes first, then the shimmer sweeps the
        // settled hero (`.then()` makes the sweep wait for the entrance).
        .animate(
          onPlay: (c) =>
              MediaQuery.disableAnimationsOf(context) ? c.stop() : null,
        )
        .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.08, duration: 500.ms, curve: Curves.easeOutCubic)
        .then()
        .shimmer(duration: 950.ms, angle: -0.5, size: 1.4);
  }
}

class _CollectionHero extends ConsumerWidget {
  const _CollectionHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(vaultStatsProvider);
    final isPro = ref.watch(authProvider.select((a) => a.isPro));
    final currency = ref.watch(currencyProvider);
    final usage = ref.watch(storageUsageProvider).valueOrNull;
    final device = ref.watch(deviceStorageProvider).valueOrNull;

    final totalBytes = stats.storageBytes.toInt();
    final usedLabel = totalBytes > 0 ? Formatters.bytes(totalBytes) : '0 B';
    final freeLabel = device != null
        ? Formatters.bytes(device.freeBytes)
        : null;
    final barFraction = device != null
        ? device.usedFraction
        : (usage != null && usage.total > 0
              ? (usage.images + usage.documents) / usage.total
              : 0);

    return Depth3DCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      depth: 8,
      tiltEnabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection value hero
          Text(
            'Collection Value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          GradientShimmerText(
            text: Formatters.money(stats.collectionValue, currency: currency),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
            duration: const Duration(milliseconds: 1400),
          ),
          const SizedBox(height: AppSpacing.md),
          // Stat badges row
          Row(
            children: [
              _StatBadge(
                icon: Icons.brush,
                label: 'Artworks',
                value: '${stats.paintings}',
                color: AppColors.secondary,
                onTap: () => context.push('/gallery'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatBadge(
                icon: Icons.person,
                label: 'Artists',
                value: '${stats.artists}',
                color: AppColors.accent,
                onTap: () => context.push('/artists'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatBadge(
                icon: Icons.description,
                label: 'Docs',
                value: '${stats.documents}',
                color: AppColors.success,
                onTap: () => context.push('/documents'),
              ),
              if (!isPro) ...[
                const SizedBox(width: AppSpacing.sm),
                _StatBadge(
                  icon: Icons.workspace_premium,
                  label: 'Plan',
                  value: 'Free',
                  color: AppColors.warning,
                  onTap: () => context.push('/upgrade'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Storage bar
          Row(
            children: [
              Icon(
                Icons.storage_outlined,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: barFraction.clamp(0.0, 1.0).toDouble(),
                        minHeight: 4,
                        backgroundColor: scheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device != null
                          ? '$freeLabel free · vault $usedLabel'
                          : 'Vault uses $usedLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPro)
                TextButton(
                  onPressed: () => context.push('/upgrade'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact stat badge with icon, label, and value.
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  final bool canEdit;

  const _QuickActions({required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <(IconData, String, VoidCallback, Color)>[
      if (canEdit)
        (
          Icons.add_photo_alternate,
          'Upload',
          () => context.push('/painting/new'),
          AppColors.emerald500,
        ),
      (
        Icons.grid_view,
        'Gallery',
        () => context.go('/gallery'),
        AppColors.cyan500,
      ),
      (
        Icons.person,
        'Artists',
        () => context.go('/artists'),
        AppColors.rose500,
      ),
      (
        Icons.insights,
        'Reports',
        () => context.push('/reports'),
        AppColors.amber500,
      ),
      (
        Icons.qr_code_scanner,
        'Scan',
        () => context.push('/scan'),
        AppColors.indigo500,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _QuickAction(
              icon: actions[i].$1,
              label: actions[i].$2,
              onTap: actions[i].$3,
              color: actions[i].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
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

    return Depth3DCard(
      padding: AppSpacing.cardPadding,
      depth: 6,
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
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
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
