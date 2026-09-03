import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
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
    final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));

    int countFor(String artistId) =>
        paintings.where((p) => p.artistId == artistId && !p.isDeleted).length;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/artist/new'),
              icon: const Icon(Icons.person_add),
              label: const Text('Add artist'),
            )
          : null,
      body: artists.isEmpty
          ? const EmptyState(
              icon: Icons.person_outline,
              title: 'No artists yet',
              subtitle:
                  'Artists are created automatically when you add paintings.',
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
                        // keep only a little breathing room under it.
                        ? const SizedBox(height: AppSpacing.xs)
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
                    padding: AppSpacing.screenPadding,
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
                  if (artist.nationality.isNotEmpty)
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
                  const SizedBox(height: AppSpacing.xs),
                  // Mini stat chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                        const SizedBox(width: 3),
                        Text(
                          '$paintingCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: gradient.$1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
