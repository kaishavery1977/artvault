import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/utils/formatters.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';

/// Best cover for a card: the stored cover, or the first image whose local
/// file actually exists when the cover is empty or its file is gone. Mirrors
/// the detail screen's images-first fallback, so a card never shows "no
/// image" while the artwork has one.
({String path, String url}) _effectiveCover(Painting p) {
  var path = p.coverImagePath;
  if (path.isEmpty || !File(path).existsSync()) {
    for (final img in p.images) {
      if (img.isNotEmpty && File(img).existsSync()) {
        path = img;
        break;
      }
    }
  }
  var url = p.coverImageUrl;
  if (url.isEmpty && p.imageUrls.isNotEmpty) url = p.imageUrls.first;
  return (path: path, url: url);
}

/// Masonry-friendly grid card for the gallery and home "recent" sections.
class PaintingGridCard extends ConsumerWidget {
  final Painting painting;
  final VoidCallback? onTap;

  /// When set, the artwork image flies into the detail screen via a Hero
  /// transition. Pass the tag at the call site so the same painting can
  /// appear in multiple mounted screens (e.g. home + gallery) without
  /// colliding.
  final String? heroTag;

  /// Position of this card inside a scrolling grid, used to cascade the
  /// entrance animation card-by-card. Leave null for no stagger.
  final int? staggerIndex;

  const PaintingGridCard({
    super.key,
    required this.painting,
    this.onTap,
    this.heroTag,
    this.staggerIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(authProvider).canEdit;
    final cover = _effectiveCover(painting);
    final image = ArtImage(
      path: cover.path,
      url: cover.url,
      fit: BoxFit.cover,
    );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (heroTag != null)
            Hero(tag: heroTag!, child: image)
          else
            image,
          // Bottom scrim for readability.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _FavoriteButton(painting: painting),
          ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  painting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  painting.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  onTap ?? () => context.push('/painting/${painting.id}'),
              onLongPress: canEdit
                  ? () => context.push('/painting/edit/${painting.id}')
                  : null,
            ),
          ),
        ],
      ),
    );

    // Cascade the entrance when the grid passes an index; respect the
    // system reduced-motion preference like the rest of the app. The delay
    // is clamped so a long gallery never leaves deep items invisible for
    // seconds — later cards settle in at a steady cadence instead.
    if (!MediaQuery.disableAnimationsOf(context)) {
      card = card
          .animate(
            delay: Duration(
              milliseconds: (staggerIndex ?? 0).clamp(0, 12) * 45,
            ),
          )
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.05, curve: Curves.easeOut);
    }

    return PressScale(child: card);
  }
}

class _FavoriteButton extends ConsumerWidget {
  final Painting painting;

  const _FavoriteButton({required this.painting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = painting.isFavorite;
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? const Color(0xFFFF6B6B) : Colors.white,
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          PaintingRepository.instance.toggleFavorite(painting.id);
        },
      ),
    );
  }
}

/// Horizontal card used by search results and list views.
class PaintingListTile extends StatelessWidget {
  final Painting painting;
  final VoidCallback? onTap;

  const PaintingListTile({super.key, required this.painting, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = _effectiveCover(painting);
    return PressScale(
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => context.push('/painting/${painting.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              children: [
                ArtImage(
                  path: cover.path,
                  url: cover.url,
                  width: 76,
                  height: 76,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        painting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${painting.artistName} · ${painting.medium}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (painting.price != null)
                            Text(
                              Formatters.money(
                                painting.price,
                                currency: painting.currency,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          const Spacer(),
                          if (painting.isFavorite)
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
