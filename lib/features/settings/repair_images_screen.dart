import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';

/// Finds paintings whose local image files are missing (e.g. after an app
/// reinstall / uninstall wiped the vault) and walks the user through
/// re-picking a replacement from the gallery.
class RepairImagesScreen extends ConsumerStatefulWidget {
  const RepairImagesScreen({super.key});

  @override
  ConsumerState<RepairImagesScreen> createState() =>
      _RepairImagesScreenState();
}

class _RepairImagesScreenState extends ConsumerState<RepairImagesScreen> {
  bool _scanning = true;
  bool _busy = false;
  List<Painting> _broken = const [];

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  /// A painting needs repair when any of its local image files are missing
  /// (or it has none). Paintings with a remote URL still available are
  /// excluded — the cloud recovery pipeline handles those automatically.
  static bool _needsRepair(Painting p) {
    if (p.isDeleted) return false;
    if (p.coverImageUrl.isNotEmpty || p.imageUrls.isNotEmpty) return false;
    final paths = p.images.isEmpty ? [p.coverImagePath] : p.images;
    if (paths.every((path) => path.isEmpty)) return true;
    return paths.any((path) => path.isNotEmpty && !File(path).existsSync());
  }

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    // Let the provider settle before scanning (it may be mid-restore).
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final all = ref.read(paintingsProvider).valueOrNull ?? const <Painting>[];
    setState(() {
      _broken = all.where(_needsRepair).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _scanning = false;
    });
  }

  Future<void> _repair(Painting painting) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.maxUploadDimension.toDouble(),
        imageQuality: 92,
      );
      if (file == null) return; // cancelled

      await PaintingRepository.instance.save(
        painting,
        newImageFiles: [File(file.path)],
        replaceImages: const [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image restored for “${painting.title}”'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _rescan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = (ref.watch(paintingsProvider).valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Repair images',
                      style: AppTheme.display(context, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                _scanning
                    ? 'Scanning your vault…'
                    : _broken.isEmpty
                    ? 'All ${total == 1 ? 'artwork' : '$total artworks'} have their images. 🎉'
                    : '${_broken.length} of $total ${_broken.length == 1 ? 'artwork needs' : 'artworks need'} an image — pick a replacement from your gallery.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _scanning
                  ? const Center(child: CircularProgressIndicator())
                  : _broken.isEmpty
                  ? _EmptyState(total: total)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: _broken.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final painting = _broken[index];
                        return GlassCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusCard,
                                  ),
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                ),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      painting.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      painting.artistName.isEmpty
                                          ? 'No artist'
                                          : painting.artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilledButton.tonalIcon(
                                onPressed: _busy
                                    ? null
                                    : () => _repair(painting),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_photo_alternate,
                                        size: 16),
                                label: const Text('Fix'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int total;
  const _EmptyState({required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: scheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nothing to repair',
            style: AppTheme.display(context, size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            total == 0
                ? 'Add an artwork to get started.'
                : 'Every artwork in your vault has an image.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
