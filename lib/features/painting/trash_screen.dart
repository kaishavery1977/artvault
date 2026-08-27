import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';

/// Recently deleted artworks. Deletes are soft — paintings land here and can
/// be restored (photos included) until they are permanently removed.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _restore(BuildContext context, Painting painting) async {
    await PaintingRepository.instance.restore(painting.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${painting.title}” restored to your vault')),
      );
    }
  }

  Future<void> _purge(BuildContext context, Painting painting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
          '“${painting.title}” and all its photos will be permanently '
          'removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await PaintingRepository.instance.purge(painting.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“${painting.title}” permanently deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final trash = PaintingRepository.instance.readTrash();

    return Scaffold(
      appBar: AppBar(title: const Text('Recently deleted')),
      body: trash.isEmpty
          ? const EmptyState(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              subtitle: 'Deleted artworks land here so you can restore them.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: trash.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final painting = trash[index];
                final tile = GlassCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: ArtImage(
                          path: painting.coverImagePath.isEmpty
                              ? null
                              : painting.coverImagePath,
                          url: painting.coverImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      painting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (painting.artistName.isNotEmpty) painting.artistName,
                        'deleted ${Formatters.date(painting.updatedAt)}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Restore',
                          icon: const Icon(Icons.restore),
                          color: scheme.primary,
                          onPressed: () => _restore(context, painting),
                        ),
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: const Icon(Icons.delete_forever_outlined),
                          color: AppColors.error,
                          onPressed: () => _purge(context, painting),
                        ),
                      ],
                    ),
                  ),
                );
                return revealListItem(
                  tile,
                  index,
                  key: ValueKey(painting.id),
                  context: context,
                );
              },
            ),
    );
  }
}
