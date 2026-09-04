import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/providers.dart';
import '../../data/models/artist.dart';

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);
    final artists = (artistsAsync.valueOrNull ?? const <Artist>[])
        .where((a) => !a.isDeleted)
        .toList();
    final loading = artistsAsync.isLoading && artistsAsync.valueOrNull == null;
    final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));

    int countFor(String artistId) =>
        paintings.where((p) => p.artistId == artistId && !p.isDeleted).length;
    final artworkTotal = paintings.where((p) => !p.isDeleted).length;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/artist/new'),
              icon: const Icon(Icons.person_add),
              label: const Text('Add artist'),
            )
          : null,
      body: loading
          ? const _ArtistsSkeletonGrid()
          : artists.isEmpty
          ? EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No artists yet',
              subtitle:
                  'Artists appear here automatically — add your '
                  'first painting to start the roster.',
              actionLabel: canEdit ? 'Add painting' : null,
              onAction: canEdit ? () => context.push('/painting/new') : null,
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(artistsProvider);
                ref.invalidate(paintingsProvider);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: kIsWeb
                        // The web shell's top bar already names this page —
                        // instead of a duplicate title, give a quick count
                        // readout of the vault's roster.
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.adaptiveSpace(AppSpacing.md),
                              AppSpacing.xs + AppSpacing.xxs,
                              context.adaptiveSpace(AppSpacing.md),
                              AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${artists.length} '
                                  '${artists.length == 1 ? 'artist' : 'artists'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$artworkTotal artworks',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.adaptiveSpace(AppSpacing.md),
                              AppSpacing.lg +
                                  MediaQuery.paddingOf(context).top * 0.4,
                              context.adaptiveSpace(AppSpacing.md),
                              AppSpacing.md,
                            ),
                            child: Text(
                              'Artists',
                              style: AppTheme.display(
                                context,
                                size: context.adaptiveFont(28),
                              ),
                            ),
                          ),
                  ),
                  SliverPadding(
                    padding: kIsWeb
                        ? EdgeInsets.symmetric(
                            horizontal: context.adaptiveSpace(AppSpacing.md),
                          )
                        : AppSpacing.screenPadding,
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => revealListItem(
                          _ArtistCard(
                            artist: artists[i],
                            paintingCount: countFor(artists[i].id),
                          ),
                          i,
                          key: ValueKey(artists[i].id),
                          context: context,
                        ),
                        childCount: artists.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            AppBreakpoints.galleryColumns(context) ~/ 2 + 1,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.95,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final int paintingCount;

  const _ArtistCard({required this.artist, required this.paintingCount});

  static const _cardGradients = <(Color, Color)>[
    (Color(0xFF667EEA), Color(0xFF764BA2)),
    (Color(0xFFF093FB), Color(0xFFF5576C)),
    (Color(0xFF4FACFE), Color(0xFF00F2FE)),
    (Color(0xFF43E97B), Color(0xFF38F9D7)),
    (Color(0xFFFA709A), Color(0xFFFEE140)),
    (Color(0xFFA18CD1), Color(0xFFFBC2EB)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient =
        _cardGradients[artist.name.hashCode.abs() % _cardGradients.length];
    final hasPhoto = artist.photoPath.isNotEmpty || artist.photoUrl.isNotEmpty;

    return Hero(
      tag: 'artist-${artist.id}',
      child: HoverLift(
        child: TiltCard(
          maxTilt: 5,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                gradient: hasPhoto
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradient.$1.withValues(alpha: 0.12),
                          gradient.$2.withValues(alpha: 0.06),
                        ],
                      ),
                border: Border.all(
                  color: gradient.$1.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                onTap: () => context.push('/artist/${artist.id}'),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar with colored ring
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [gradient.$1, gradient.$2],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surface,
                          ),
                          child: Avatar(
                            name: artist.name,
                            imagePath: artist.photoPath,
                            imageUrl: artist.photoUrl,
                            radius: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // Worded painting count, directly under the name — the
                      // bare number read as a mysterious "/ 1" glyph.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gradient.$1.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brush, size: 11, color: gradient.$1),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$paintingCount '
                                '${L10n.t(context, paintingCount == 1 ? 'painting' : 'paintings')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: gradient.$1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (artist.nationality.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          artist.nationality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer roster grid shown while artists are first loading — mirrors the
/// real grid's columns and aspect so content doesn't jump when it lands.
class _ArtistsSkeletonGrid extends StatelessWidget {
  const _ArtistsSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pad = kIsWeb
        ? EdgeInsets.symmetric(horizontal: context.adaptiveSpace(AppSpacing.md))
        : AppSpacing.screenPadding;
    return GridView.builder(
      padding: pad,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppBreakpoints.galleryColumns(context) ~/ 2 + 1,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.95,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHigh,
        highlightColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        child: const SkeletonBox(height: double.infinity),
      ),
    );
  }
}
