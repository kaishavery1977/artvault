import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/app_user.dart';
import '../../data/models/art_document.dart';
import '../../data/models/artist.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/artist_repository.dart';
import '../../data/repositories/painting_repository.dart';

/// Finds vault files whose local copies are missing (e.g. after an app
/// reinstall / uninstall wiped the vault) and walks the user through
/// re-picking replacements from the gallery / files.
///
/// Covers four cases:
///  - paintings whose image files are gone,
///  - artists whose profile photos are gone,
///  - documents whose files are gone,
///  - the signed-in user's own profile photo.
class RepairImagesScreen extends ConsumerStatefulWidget {
  const RepairImagesScreen({super.key});

  /// A painting needs repair when any of its local image files are missing
  /// (or it has none). Paintings with a remote URL still available are
  /// excluded — the cloud recovery pipeline handles those automatically.
  static bool needsRepair(Painting p) {
    if (p.isDeleted) return false;
    if (p.coverImageUrl.isNotEmpty || p.imageUrls.isNotEmpty) return false;
    final paths = p.images.isEmpty ? [p.coverImagePath] : p.images;
    // No stored image at all → nothing to repair (the user simply never
    // added one); only *lost* files need re-picking.
    if (paths.every((path) => path.isEmpty)) return false;
    return paths.any((path) => path.isNotEmpty && !File(path).existsSync());
  }

  /// Whether the signed-in user's profile photo file is missing (and there's
  /// no remote copy to fall back on).
  static bool profilePhotoMissing(AppUser? user) {
    if (user == null) return false;
    if (user.photoUrl.isNotEmpty) return false;
    return user.photoPath.isNotEmpty && !File(user.photoPath).existsSync();
  }

  /// An artist needs repair when their photo file is missing and there is no
  /// remote copy to fall back on.
  static bool artistPhotoMissing(Artist a) {
    if (a.isDeleted) return false;
    if (a.photoUrl.isNotEmpty) return false;
    return a.photoPath.isNotEmpty && !File(a.photoPath).existsSync();
  }

  /// A document needs repair when its file is missing and there is no remote
  /// copy to fall back on.
  static bool documentMissing(ArtDocument d) {
    if (d.isDeleted) return false;
    if (d.remoteUrl.isNotEmpty) return false;
    return d.localPath.isNotEmpty && !File(d.localPath).existsSync();
  }

  @override
  ConsumerState<RepairImagesScreen> createState() => _RepairImagesScreenState();
}

class _RepairImagesScreenState extends ConsumerState<RepairImagesScreen> {
  bool _scanning = true;
  bool _busy = false;
  List<Painting> _brokenPaintings = const [];
  List<Artist> _brokenArtists = const [];
  List<ArtDocument> _brokenDocs = const [];

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    // Let the providers settle before scanning (they may be mid-restore).
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final paintings =
        ref.read(paintingsProvider).valueOrNull ?? const <Painting>[];
    final artists = ref.read(artistsProvider).valueOrNull ?? const <Artist>[];
    final docs =
        ref.read(documentsProvider).valueOrNull ?? const <ArtDocument>[];
    setState(() {
      _brokenPaintings =
          paintings.where(RepairImagesScreen.needsRepair).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _brokenArtists =
          artists.where(RepairImagesScreen.artistPhotoMissing).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _brokenDocs = docs.where(RepairImagesScreen.documentMissing).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _scanning = false;
    });
  }

  Future<void> _fixProfilePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.coverThumbDimension.toDouble(),
        imageQuality: 85,
      );
      if (file == null) return; // cancelled

      final path = await FileStorageService.instance.importImage(
        File(file.path),
      );
      await AuthRepository.instance.updateProfile(photoPath: path);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore profile photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repairPainting(Painting painting) async {
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

  Future<void> _repairArtist(Artist artist) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.coverThumbDimension.toDouble(),
        imageQuality: 85,
      );
      if (file == null) return; // cancelled

      await ArtistRepository.instance.save(artist, photoFile: File(file.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo restored for ${artist.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _rescan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repairDocument(ArtDocument doc) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (picked == null || picked.files.isEmpty) return; // cancelled
      final path = picked.files.single.path;
      if (path == null) return;

      await DocumentRepository.instance.restoreFile(doc.id, File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File restored for “${doc.name}”'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _rescan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not restore file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _totalBroken =>
      _brokenPaintings.length + _brokenArtists.length + _brokenDocs.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider.select((a) => a.user));
    final profileMissing = RepairImagesScreen.profilePhotoMissing(user);

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
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Repair files',
                      style: AppTheme.display(
                        context,
                        size: context.adaptiveFont(26),
                      ),
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
                    : _totalBroken == 0 && !profileMissing
                    ? 'Everything has its files. 🎉'
                    : '${_totalBroken + (profileMissing ? 1 : 0)} '
                          '${_totalBroken + (profileMissing ? 1 : 0) == 1 ? 'file needs' : 'files need'} '
                          'a replacement — pick from your gallery or files.',
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
                  : _totalBroken == 0 && !profileMissing
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _items[index],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The repair cards in display order: profile photo, then artists, then
  /// documents, then paintings.
  List<Widget> get _items {
    final user = ref.read(authProvider).user;
    final items = <Widget>[];

    if (RepairImagesScreen.profilePhotoMissing(user)) {
      items.add(_ProfilePhotoCard(busy: _busy, onFix: _fixProfilePhoto));
    }

    for (final artist in _brokenArtists) {
      items.add(
        _RepairCard(
          icon: Icons.person_off_outlined,
          title: artist.name,
          subtitle: 'Artist profile photo missing',
          busy: _busy,
          onFix: () => _repairArtist(artist),
        ),
      );
    }

    for (final doc in _brokenDocs) {
      items.add(
        _RepairCard(
          icon: Icons.description_outlined,
          title: doc.name,
          subtitle: 'Document file missing',
          busy: _busy,
          onFix: () => _repairDocument(doc),
        ),
      );
    }

    for (final painting in _brokenPaintings) {
      items.add(
        _RepairCard(
          icon: Icons.broken_image_outlined,
          title: painting.title,
          subtitle: painting.artistName.isEmpty
              ? 'Artwork image missing'
              : '${painting.artistName} — artwork image missing',
          busy: _busy,
          onFix: () => _repairPainting(painting),
        ),
      );
    }

    return items;
  }
}

class _RepairCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onFix;

  const _RepairCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Icon(icon, color: scheme.onSurface.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onFix,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate, size: 16),
            label: const Text('Fix'),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onFix;

  const _ProfilePhotoCard({required this.busy, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.person_off_outlined,
              size: 26,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your profile photo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Missing after the reinstall — pick a new one.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onFix,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo, size: 16),
            label: const Text('Fix'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
          Text('Nothing to repair', style: AppTheme.display(context, size: 20)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Every image and document in your vault is present.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
