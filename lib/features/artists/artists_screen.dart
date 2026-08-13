import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
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
    final canEdit = ref.watch(authProvider).canEdit;

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
              subtitle: 'Artists are created automatically when you add paintings.',
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text('Artists', style: AppTheme.display(context, size: 28)),
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
                        context: context,
                      ),
                      childCount: artists.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: AppBreakpoints.galleryColumns(context) ~/ 2 + 1,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.95,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final int paintingCount;

  const _ArtistCard({required this.artist, required this.paintingCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: AppSpacing.cardPadding,
      onTap: () => context.push('/artist/${artist.id}'),
      child: Column(
        children: [
          Avatar(
            name: artist.name,
            imagePath: artist.photoPath,
            imageUrl: artist.photoUrl,
            radius: 34,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            artist.nationality.isEmpty
                ? '$paintingCount painting${paintingCount == 1 ? '' : 's'}'
                : '${artist.nationality} · $paintingCount works',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.transparent),
        ],
      ),
    );
  }
}
