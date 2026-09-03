import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/premium/premium.dart';
import '../../data/models/painting.dart';
import '../gallery/painting_card.dart';

/// Web-optimized home screen.
///
/// Premium, not console: a layered welcome hero (serif statement + an
/// interactive floating artwork stage that tilts with the pointer), a quick
/// action band, a responsive recent-uploads grid, and an AI insights card.
/// Layout adapts to the viewport (hero splits wide, stacks narrow; the grid
/// reflows column count) and every entrance is reduced-motion aware.
class HomeScreenWeb extends ConsumerWidget {
  const HomeScreenWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final paintingsAsync = ref.watch(paintingsProvider);
    final canEdit = auth.canEdit;

    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();
    final recent = [...paintings]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final docCount = ref.watch(documentsProvider).valueOrNull?.length ?? 0;
    final totalValue = paintings.fold<double>(
      0.0,
      (s, p) => s + (p.price ?? 0),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _entrance(
            context,
            _WelcomeHero(
              userName: auth.user?.displayName ?? 'Guest',
              paintings: recent,
              canEdit: canEdit,
              docCount: docCount,
              totalValue: totalValue,
            ),
          ),
        ),
        // Quick actions
        SliverToBoxAdapter(child: _QuickActionsWeb(canEdit: canEdit)),
        // Recent uploads
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recent uploads',
              subtitle:
                  '${recent.length} artwork${recent.length == 1 ? '' : 's'} in your vault',
              onAction: () => context.go('/gallery'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: context.adaptiveSpace(AppSpacing.md),
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final cols = _gridColumns(constraints.crossAxisExtent);
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _HoverPaintingCard(
                      painting: recent.take(8).toList()[i],
                      heroTag: 'home-${recent[i].id}',
                      staggerIndex: i,
                    ),
                    childCount: math.min(recent.length, 8),
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.82,
                  ),
                );
              },
            ),
          ),
        ],
        // AI Insights
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.adaptiveSpace(AppSpacing.md),
                AppSpacing.lg,
                context.adaptiveSpace(AppSpacing.md),
                0,
              ),
              child: _AiInsightsWeb(paintings: recent),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 56)),
      ],
    );
  }

  /// Responsive column count for the recent-uploads grid.
  int _gridColumns(double width) {
    if (width < 560) return 2;
    if (width < 860) return 3;
    if (width < 1240) return 4;
    return 5;
  }
}

/// Layered welcome hero: serif statement + gradient name on the left, a
/// floating gallery stage on the right (wide screens only). The stage is
/// purely decorative — real navigation lives in the CTAs and quick actions.
class _WelcomeHero extends ConsumerWidget {
  final String userName;
  final List<Painting> paintings;
  final bool canEdit;
  final int docCount;
  final double totalValue;

  const _WelcomeHero({
    required this.userName,
    required this.paintings,
    required this.canEdit,
    required this.docCount,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionOk = !MediaQuery.disableAnimationsOf(context);

    // Artworks that can actually be shown as cover tiles.
    final coverable = paintings
        .where((p) => p.coverImageUrl.isNotEmpty || p.imageUrls.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.adaptiveSpace(AppSpacing.md),
        AppSpacing.xxs,
        context.adaptiveSpace(AppSpacing.md),
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.violet900.withValues(alpha: 0.55),
                        AppColors.cyan900.withValues(alpha: 0.30),
                        AppColors.rose900.withValues(alpha: 0.18),
                      ]
                    : [
                        AppColors.violet100.withValues(alpha: 0.9),
                        AppColors.cyan100.withValues(alpha: 0.6),
                        AppColors.rose100.withValues(alpha: 0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXxxl),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.white.withValues(alpha: 0.7),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : AppColors.violet500.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft interior glows for depth.
                if (motionOk)
                  Positioned(
                    right: -60,
                    top: -80,
                    child: _glow(
                      size: 300,
                      color: scheme.secondary.withValues(
                        alpha: isDark ? 0.14 : 0.16,
                      ),
                    ),
                  ),
                Positioned(
                  left: -70,
                  bottom: -90,
                  child: _glow(
                    size: 260,
                    color: scheme.primary.withValues(
                      alpha: isDark ? 0.12 : 0.10,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _HeroCopy(
                                userName: userName,
                                canEdit: canEdit,
                                docCount: docCount,
                                totalValue: totalValue,
                                artworkCount: paintings.length,
                                wide: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              width: 360,
                              height: 380,
                              child: _ArtStage(
                                coverable: coverable,
                                canEdit: canEdit,
                              ),
                            ),
                          ],
                        )
                      : _HeroCopy(
                          userName: userName,
                          canEdit: canEdit,
                          docCount: docCount,
                          totalValue: totalValue,
                          artworkCount: paintings.length,
                          wide: false,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _glow({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Single shared entrance for home sections: fade + slight rise. Uses
/// [RevealEntrance] so the whole delay is folded into the animation curve
/// (no timers) and reduced motion renders statically.
Widget _entrance(
  BuildContext context,
  Widget child, {
  Duration duration = const Duration(milliseconds: 560),
  Duration delay = Duration.zero,
  double beginOffset = 0.02,
}) {
  final static = MediaQuery.disableAnimationsOf(context);
  return RevealEntrance(
    duration: duration,
    delay: static ? Duration.zero : delay,
    beginOffset: static ? 0 : beginOffset,
    reducedMotion: static,
    child: child,
  );
}

/// Eyebrow + serif statement + copy + CTAs + stat chips.
class _HeroCopy extends StatelessWidget {
  final String userName;
  final bool canEdit;
  final int docCount;
  final double totalValue;
  final int artworkCount;
  final bool wide;

  const _HeroCopy({
    required this.userName,
    required this.canEdit,
    required this.docCount,
    required this.totalValue,
    required this.artworkCount,
    required this.wide,
  });

  String get _firstName {
    final trimmed = userName.trim();
    if (trimmed.isEmpty || trimmed == 'Guest') return 'collector';
    return trimmed.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading = wide
        ? 40.0
        : (MediaQuery.sizeOf(context).width < 520 ? 30.0 : 36.0);
    final copySize = wide ? 15.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ARTVAULT · PRIVATE COLLECTION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Good ${_greeting()},',
          style: AppTheme.display(context, size: heading),
        ),
        const SizedBox(height: 4),
        GradientShimmerText(
          text: _firstName,
          style: AppTheme.display(context, size: heading),
          colors: [scheme.primary, scheme.secondary, scheme.tertiary],
          duration: const Duration(milliseconds: 1400),
        ),
        const SizedBox(height: 12),
        Text(
          'Your art collection at a glance — catalogue, value and provenance '
          'in one calm, private place.',
          style: TextStyle(
            fontSize: copySize,
            height: 1.5,
            color: scheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (canEdit)
              ElevatedButton.icon(
                onPressed: () => context.push('/painting/new'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add artwork'),
              ),
            OutlinedButton.icon(
              onPressed: () => context.go('/gallery'),
              icon: const Icon(Icons.grid_view_rounded, size: 17),
              label: const Text('Browse gallery'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        // Value chips.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ValueChip(
              icon: Icons.brush_rounded,
              color: AppColors.cyan500,
              label: 'Artworks',
              value: AnimatedCountUp(
                value: artworkCount.toDouble(),
                style: _chipValueStyle(context),
                format: (v) => v.round().toString(),
              ),
            ),
            _ValueChip(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.amber500,
              label: 'Value',
              value: AnimatedCountUp(
                value: totalValue,
                style: _chipValueStyle(context),
                format: (v) => Formatters.money(v),
              ),
            ),
            _ValueChip(
              icon: Icons.description_rounded,
              color: AppColors.emerald500,
              label: 'Documents',
              value: AnimatedCountUp(
                value: docCount.toDouble(),
                style: _chipValueStyle(context),
                format: (v) => v.round().toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _chipValueStyle(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: Theme.of(context).colorScheme.onSurface,
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

/// One compact hero stat chip: tinted icon tile + animated value + label.
class _ValueChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget value;

  const _ValueChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 9),
          value,
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive floating artwork composition. Real covers fan around a main
/// tile (tilting with the pointer, drifting gently); with no artwork yet it
/// shows an invitation tile so the composition never feels hollow.
class _ArtStage extends StatefulWidget {
  final List<Painting> coverable;
  final bool canEdit;

  const _ArtStage({required this.coverable, required this.canEdit});

  @override
  State<_ArtStage> createState() => _ArtStageState();
}

class _ArtStageState extends State<_ArtStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  bool _driftStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery (and thus the reduced-motion preference) is only available
    // from didChangeDependencies onward — start the drift there, once.
    if (!_driftStarted && !MediaQuery.disableAnimationsOf(context)) {
      _driftStarted = true;
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionOk = !MediaQuery.disableAnimationsOf(context);
    final coverable = widget.coverable;

    Widget composition = ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back glow.
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withValues(alpha: isDark ? 0.30 : 0.20),
                  scheme.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (coverable.isEmpty) ...[
            // Invitation tile.
            Transform.rotate(
              angle: -0.03,
              child: Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.85),
                      scheme.secondary.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.palette_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.canEdit
                            ? 'Add your first artwork'
                            : 'Your vault is ready',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 52,
              child: _FloatingTag(
                icon: Icons.arrow_upward_rounded,
                label: widget.canEdit ? 'Upload' : 'Browse',
                onTap: widget.canEdit
                    ? () => context.push('/painting/new')
                    : () => context.go('/gallery'),
              ),
            ),
          ] else ...[
            // Secondary covers fanning behind the main tile.
            if (coverable.length > 1)
              Positioned(
                left: 8,
                bottom: 58,
                child: Transform.rotate(
                  angle: -0.14,
                  child: _CoverTile(
                    painting: coverable[1],
                    width: 128,
                    height: 168,
                    opacity: 0.92,
                  ),
                ),
              ),
            if (coverable.length > 2)
              Positioned(
                right: 2,
                top: 46,
                child: Transform.rotate(
                  angle: 0.12,
                  child: _CoverTile(
                    painting: coverable[2],
                    width: 112,
                    height: 148,
                    opacity: 0.9,
                  ),
                ),
              ),
            // Main cover.
            Transform.rotate(
              angle: 0.02,
              child: _CoverTile(
                painting: coverable.first,
                width: 236,
                height: 316,
                opacity: 1,
              ),
            ),
            // Floating price tag (when the main piece is priced).
            if ((coverable.first.price ?? 0) > 0)
              Positioned(
                right: 0,
                bottom: 40,
                child: _FloatingTag(
                  icon: Icons.sell_rounded,
                  label: Formatters.money(coverable.first.price ?? 0),
                  onTap: null,
                ),
              ),
          ],
        ],
      ),
    );

    // Gentle vertical drift, GPU-cheap transform only.
    if (motionOk) {
      composition = AnimatedBuilder(
        animation: _drift,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 5 * math.sin(_drift.value * 2 * math.pi)),
          child: child,
        ),
        child: composition,
      );
    }

    // Pointer tilt on the whole stage (reduced-motion renders static).
    if (motionOk) {
      composition = TiltCard(maxTilt: 4, child: composition);
    }

    return _entrance(
      context,
      composition,
      duration: const Duration(milliseconds: 700),
      delay: const Duration(milliseconds: 120),
      beginOffset: 0.03,
    );
  }
}

/// Small glass pill that floats near the stage (price, hint chips).
class _FloatingTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FloatingTag({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF171A28).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}

/// Framed cover tile — the same [ArtImage] pipeline as the gallery so cloud
/// images resolve identically, inside a gallery-style frame.
class _CoverTile extends StatelessWidget {
  final Painting painting;
  final double width;
  final double height;
  final double opacity;

  const _CoverTile({
    required this.painting,
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = painting.coverImageUrl.isNotEmpty
        ? painting.coverImageUrl
        : (painting.imageUrls.isNotEmpty ? painting.imageUrls.first : '');

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Opacity(
        opacity: opacity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox.expand(
            child: coverUrl.isEmpty
                ? _CoverPlaceholder(painting: painting)
                : ArtImage(url: coverUrl, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Gradient monogram placeholder for covers with no uploaded image yet.
class _CoverPlaceholder extends StatelessWidget {
  final Painting painting;
  const _CoverPlaceholder({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet500, AppColors.cyan400],
        ),
      ),
      child: Center(
        child: Text(
          (painting.title.isEmpty ? '?' : painting.title[0]).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Shared section header row used across the home sections.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _entrance(
      context,
      Padding(
        padding: EdgeInsets.fromLTRB(
          context.adaptiveSpace(AppSpacing.md),
          AppSpacing.xl,
          context.adaptiveSpace(AppSpacing.md),
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onAction,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick actions band: upload / gallery / artists / reports as a row of
/// tinted glass cards (2×2 on narrow layouts).
class _QuickActionsWeb extends ConsumerWidget {
  final bool canEdit;
  const _QuickActionsWeb({required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_WebAction>[
      if (canEdit)
        _WebAction(
          Icons.add_photo_alternate_rounded,
          'Upload',
          'Add new artwork',
          () => context.push('/painting/new'),
          AppColors.emerald500,
        ),
      _WebAction(
        Icons.grid_view_rounded,
        'Gallery',
        'Browse your collection',
        () => context.go('/gallery'),
        AppColors.cyan500,
      ),
      _WebAction(
        Icons.person_outline_rounded,
        'Artists',
        'Manage your artists',
        () => context.go('/artists'),
        AppColors.rose500,
      ),
      _WebAction(
        Icons.insights_rounded,
        'Reports',
        'Insights & valuation',
        () => context.push('/reports'),
        AppColors.amber500,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.adaptiveSpace(AppSpacing.md),
        AppSpacing.md + AppSpacing.xs,
        context.adaptiveSpace(AppSpacing.md),
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideRow = constraints.maxWidth >= 780;
          if (wideRow) {
            return Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: _WebActionCard(action: actions[i])),
                ],
              ],
            );
          }
          final half = (constraints.maxWidth - AppSpacing.md) / 2;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final a in actions)
                SizedBox(
                  width: half,
                  child: _WebActionCard(action: a),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WebAction {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final Color color;
  const _WebAction(
    this.icon,
    this.label,
    this.description,
    this.onTap,
    this.color,
  );
}

class _WebActionCard extends StatefulWidget {
  final _WebAction action;
  const _WebActionCard({required this.action});

  @override
  State<_WebActionCard> createState() => _WebActionCardState();
}

class _WebActionCardState extends State<_WebActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: _hovered
                ? action.color.withValues(alpha: isDark ? 0.12 : 0.08)
                : (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.03,
                  ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: _hovered
                  ? action.color.withValues(alpha: 0.35)
                  : (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.07,
                    ),
              width: 0.8,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      action.color.withValues(alpha: _hovered ? 0.5 : 0.3),
                      action.color.withValues(alpha: _hovered ? 0.3 : 0.14),
                    ],
                  ),
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: _hovered ? 1.12 : 1.0,
                  child: Icon(action.icon, size: 21, color: action.color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: _hovered
                    ? action.color
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painting card with hover lift + ring for the web home grid.
class _HoverPaintingCard extends StatefulWidget {
  final Painting painting;
  final String heroTag;
  final int staggerIndex;

  const _HoverPaintingCard({
    required this.painting,
    required this.heroTag,
    required this.staggerIndex,
  });

  @override
  State<_HoverPaintingCard> createState() => _HoverPaintingCardState();
}

class _HoverPaintingCardState extends State<_HoverPaintingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/painting/${widget.painting.id}'),
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: _hovered
                    ? scheme.primary.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: PaintingGridCard(
              painting: widget.painting,
              heroTag: widget.heroTag,
              staggerIndex: widget.staggerIndex,
            ),
          ),
        ),
      ),
    );
  }
}

/// AI insights card — collection pulse in a tilting glass card.
class _AiInsightsWeb extends StatelessWidget {
  final List<Painting> paintings;
  const _AiInsightsWeb({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final mediumCounts = <String, int>{};
    final artistCounts = <String, int>{};
    for (final p in paintings) {
      if (p.medium.isNotEmpty) {
        mediumCounts[p.medium] = (mediumCounts[p.medium] ?? 0) + 1;
      }
      if (p.artistName.isNotEmpty) {
        artistCounts[p.artistName] = (artistCounts[p.artistName] ?? 0) + 1;
      }
    }

    String? topKey(Map<String, int> c) {
      String? best;
      var bestCount = 0;
      c.forEach((k, v) {
        if (v > bestCount) {
          best = k;
          bestCount = v;
        }
      });
      return best;
    }

    return _entrance(
      context,
      Depth3DCard(
        padding: const EdgeInsets.all(24),
        depth: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rows = <Widget>[
              _InsightRowWeb(
                icon: Icons.palette_outlined,
                label: 'Most common medium',
                value: topKey(mediumCounts) ?? '—',
              ),
              _InsightRowWeb(
                icon: Icons.person_outline,
                label: 'Most collected artist',
                value: topKey(artistCounts) ?? '—',
              ),
              _InsightRowWeb(
                icon: Icons.auto_graph,
                label: 'Total artworks',
                value: '${paintings.length}',
              ),
            ];
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _insightsTitle(context),
                  const SizedBox(height: 18),
                  for (final r in rows) r,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _insightsTitle(context),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(width: 24),
                      Expanded(child: rows[i]),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
      duration: const Duration(milliseconds: 560),
      delay: const Duration(milliseconds: 150),
      beginOffset: 0.03,
    );
  }

  Widget _insightsTitle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.auto_awesome, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          'AI Insights',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _InsightRowWeb extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InsightRowWeb({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: scheme.primary),
        ),
        const SizedBox(width: 11),
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
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
