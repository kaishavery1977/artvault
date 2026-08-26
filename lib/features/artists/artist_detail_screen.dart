import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/artist.dart';
import '../../data/repositories/artist_repository.dart';
import '../gallery/painting_card.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  Future<void> _confirmDelete(String name, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete artist?'),
        content: Text('$name will be removed. Paintings stay in your vault.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ArtistRepository.instance.delete(widget.artistId);
      if (mounted) context.pop();
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final artist = ref.watch(artistsProvider).valueOrNull?.cast<Artist?>()
            .firstWhere((a) => a?.id == widget.artistId, orElse: () => null) ??
        ArtistRepository.instance.get(widget.artistId);
    final paintings = (ref.watch(paintingsProvider).valueOrNull ?? const [])
        .where((p) => p.artistId == widget.artistId && !p.isDeleted)
        .toList();
    final canEdit = ref.watch(authProvider).canEdit;

    if (artist == null) {
      return const Scaffold(body: Center(child: Text('Artist not found')));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: const BackButton(),
            title: Text(artist.name),
            actions: [
              if (canEdit)
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        context.push('/artist/edit/${artist.id}');
                      case 'delete':
                        _confirmDelete(artist.name, artist.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...staggerReveal([
                  Center(
                    child: Column(
                      children: [
                        Avatar(
                          name: artist.name,
                          imagePath: artist.photoPath,
                          imageUrl: artist.photoUrl,
                          radius: 48,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(artist.name, style: AppTheme.display(context, size: context.adaptiveFont(26))),
                        if (artist.nationality.isNotEmpty)
                          Text(
                            artist.nationality,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (artist.biography.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(title: 'Biography'),
                    Text(artist.biography, style: const TextStyle(height: 1.55)),
                  ],
                  if (artist.awards.isNotEmpty) ...[
                    SectionHeader(title: 'Awards'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final award in artist.awards)
                          TagChip(label: award, color: AppColors.accent),
                      ],
                    ),
                  ],
                  if (artist.exhibitions.isNotEmpty) ...[
                    SectionHeader(title: 'Exhibitions'),
                    for (final exhibition in artist.exhibitions)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.museum_outlined),
                        title: Text(exhibition),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _ContactCard(artist: artist, onOpen: _open),
                  SectionHeader(
                    title: 'Paintings',
                    actionLabel: paintings.isEmpty ? null : '${paintings.length} works',
                  ),
                  if (paintings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('No paintings associated yet.'),
                    )
                  else
                    GridView.count(
                      crossAxisCount: AppBreakpoints.galleryColumns(context),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.82,
                      children: [
                        for (final painting in paintings)
                          PaintingGridCard(painting: painting),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  ], context: context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Artist artist;
  final ValueChanged<String> onOpen;

  const _ContactCard({required this.artist, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String?)>[
      (Icons.phone_outlined, 'Phone', artist.phone),
      (Icons.mail_outline, 'Email', artist.email),
      (Icons.public, 'Website', artist.website),
      (Icons.camera_alt_outlined, 'Instagram', artist.instagram),
      (Icons.facebook, 'Facebook', artist.facebook),
    ].where((e) => e.$3 != null && e.$3!.isNotEmpty).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(entry.$1, size: 20),
              title: Text(entry.$2, style: const TextStyle(fontSize: 13)),
              trailing: Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () => onOpen(entry.$3!),
            ),
        ],
      ),
    );
  }
}
