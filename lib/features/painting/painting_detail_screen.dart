import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/pro_limits.dart';
import '../../core/theme/adaptive_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/export_service.dart';
import '../../core/services/public_gallery_service.dart';
import '../../core/services/qr_service.dart';
import '../../core/services/share_service.dart';
import '../../features/pro/pro_celebration.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../features/documents/documents_screen.dart'
    show RenameDocumentDialog;
import 'painting_lightbox_screen.dart';
import '../../data/models/art_document.dart';
import '../../data/models/condition_report.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/condition_report_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/painting_repository.dart';
import 'condition_report_dialog.dart';
import '../gallery/painting_card.dart';

/// Full artwork view: swipable zoomable images, complete metadata,
/// documents, QR, AI insights, related works and export/share actions.
class PaintingDetailScreen extends ConsumerStatefulWidget {
  final String paintingId;

  const PaintingDetailScreen({super.key, required this.paintingId});

  @override
  ConsumerState<PaintingDetailScreen> createState() =>
      _PaintingDetailScreenState();
}

class _PaintingDetailScreenState extends ConsumerState<PaintingDetailScreen> {
  int _imageIndex = 0;

  Future<void> _shareSheet(Painting painting) async {
    final result = await showModalBottomSheet<_ShareAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ShareSheet(painting: painting),
    );
    if (result == null || !mounted) return;
    final share = ShareService.instance;
    switch (result) {
      case _ShareAction.image:
        await share.shareImage(painting);
      case _ShareAction.withDescription:
        await share.shareWithDescription(painting);
      case _ShareAction.watermark:
        await share.shareWatermarked(painting);
      case _ShareAction.qr:
        await share.shareQr(painting);
      case _ShareAction.pdf:
        final pdf = await ExportService.instance.buildPaintingPdf(painting);
        await share.sharePdf(pdf, '${painting.title}_catalog.pdf');
    }
  }

  Future<void> _confirmDelete(Painting painting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to trash?'),
        content: Text(
          '“${painting.title}” will be moved to Trash. You can restore it '
          'anytime from Settings → Recently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final id = painting.id;
      final title = painting.title;
      await PaintingRepository.instance.delete(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('“$title” moved to trash'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => PaintingRepository.instance.restore(id),
            ),
          ),
        );
      context.pop();
    }
  }

  Future<void> _addDocument(Painting painting) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return;

    final type = await _pickDocumentType();
    if (type == null || !mounted) return;
    await DocumentRepository.instance.add(
      paintingId: painting.id,
      type: type,
      name: file.name,
      file: File(path),
    );
  }

  Future<String?> _pickDocumentType() {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in AppConstants.documentTypes)
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(type),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(ArtDocument doc) async {
    final file = await DocumentRepository.instance.openFile(doc);
    if (file == null || !mounted) return;
    final share = ShareService.instance;
    await share.shareFile(file.path, text: doc.name);
  }

  @override
  Widget build(BuildContext context) {
    final painting = ref.watch(paintingByIdProvider(widget.paintingId));
    // Visual-similarity rail: the AI scorer blends the perceptual hash with
    // palette, tags, category/medium/style and tonal character — so works
    // that *look* alike surface, not just same-artist / same-category ones.
    final related = painting == null
        ? const <Painting>[]
        : PaintingRepository.instance
              .findSimilar(painting)
              .map((m) => m.painting)
              .toList();

    if (painting == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.image_search_outlined,
          title: 'Painting not found',
          subtitle:
              'This artwork is not in your vault. It may live on another '
              'device — scan its QR code again to add it here.',
        ),
      );
    }

    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));
    final images = painting.images.isEmpty
        ? <String>[painting.coverImagePath]
        : painting.images;
    final urls = painting.imageUrls.isEmpty
        ? <String>[painting.coverImageUrl]
        : painting.imageUrls;

    // In landscape, shrink the hero image area since vertical space is limited.
    final mq = MediaQuery.of(context);
    final heroHeight = mq.size.width > mq.size.height ? 220.0 : 360.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: heroHeight,
            pinned: true,
            stretch: true,
            leading: const BackButton(),
            actions: [
              IconButton(
                tooltip: painting.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                icon: Icon(
                  painting.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: painting.isFavorite ? const Color(0xFFFF6B6B) : null,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  PaintingRepository.instance.toggleFavorite(painting.id);
                },
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareSheet(painting),
              ),
              if (canEdit)
                PopupMenuButton<_MoreAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _MoreAction.edit:
                        context.push('/painting/edit/${painting.id}');
                      case _MoreAction.delete:
                        _confirmDelete(painting);
                      case _MoreAction.download:
                        ShareService.instance.shareImage(painting);
                      case _MoreAction.print:
                        ExportService.instance.printCatalog([painting]);
                      case _MoreAction.exportPdf:
                        _exportPdf(painting);
                      case _MoreAction.exportExcel:
                        _exportExcel([painting]);
                      case _MoreAction.publicGallery:
                        _publicGallery(painting);
                      case _MoreAction.manageGalleryLink:
                        _manageGalleryLink();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _MoreAction.edit,
                      child: Text('Edit details'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.download,
                      child: Text('Share image'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.print,
                      child: Text('Print'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.exportPdf,
                      child: Text('Export as PDF'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.exportExcel,
                      child: Text('Export to Excel'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.publicGallery,
                      child: Text('Public gallery'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.manageGalleryLink,
                      child: Text('Manage gallery link'),
                    ),
                    PopupMenuItem(
                      value: _MoreAction.delete,
                      child: Text('Delete painting'),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero flight target: tapping opens the full-screen
                  // lightbox, and the image flies from the gallery grid.
                  GestureDetector(
                    onTap: () => context.push(
                      '/lightbox',
                      extra: LightboxArgs(
                        paintings: [painting, ...related],
                        initialIndex: 0,
                      ),
                    ),
                    child: Hero(
                      tag: 'painting-${painting.id}',
                      // A slow settle-zoom as the artwork arrives — the
                      // lens finding its focus before the metadata reads in.
                      child: KenBurns(
                        begin: 1.1,
                        duration: const Duration(milliseconds: 2000),
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _imageIndex = i),
                          itemBuilder: (context, i) => InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: ArtImage(
                              path: images[i],
                              url: i < urls.length ? urls[i] : null,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Museum-lit vignette over the artwork.
                  Positioned.fill(child: FilmVignette(strength: 0.22)),
                  if (images.length > 1)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _imageIndex ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: i == _imageIndex ? 0.95 : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: staggerReveal(
                  [
                    _TitleBlock(painting: painting, canEdit: canEdit),
                    const SizedBox(height: AppSpacing.lg),
                    _InfoGrid(painting: painting),
                    const SizedBox(height: AppSpacing.lg),
                    if (painting.description.isNotEmpty) ...[
                      SectionHeader(title: 'Description'),
                      Text(
                        painting.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ],
                    if (painting.tags.isNotEmpty ||
                        painting.aiTags.isNotEmpty) ...[
                      SectionHeader(title: 'Tags'),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final t in {
                            ...painting.tags,
                            ...painting.aiTags,
                          })
                            TagChip(label: t),
                        ],
                      ),
                    ],
                    if (painting.dominantColors.isNotEmpty) ...[
                      SectionHeader(title: 'AI palette'),
                      _Palette(colors: painting.dominantColors),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _AiAnalysisCard(painting: painting),
                    SectionHeader(title: 'Documents'),
                    _DocumentsSection(
                      paintingId: painting.id,
                      canEdit: canEdit,
                      onAdd: () => _addDocument(painting),
                      onOpen: _openDocument,
                    ),
                    SectionHeader(title: 'Condition'),
                    _ConditionSection(
                      paintingId: painting.id,
                      canEdit: canEdit,
                    ),
                    SectionHeader(title: 'QR code'),
                    _QrCard(painting: painting),
                    if (related.isNotEmpty) ...[
                      SectionHeader(title: 'Similar paintings'),
                      SizedBox(
                        height: context.scaled(190),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: related.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, i) => SizedBox(
                            width: 150,
                            child: PaintingGridCard(
                              painting: related[i],
                              heroTag: 'painting-${related[i].id}',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  initialDelay: const Duration(milliseconds: 150),
                  interval: const Duration(milliseconds: 70),
                  context: context,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(Painting painting) async {
    final pdf = await ExportService.instance.buildPaintingPdf(painting);
    if (!mounted) return;
    await ShareService.instance.sharePdf(pdf, '${painting.title}_info.pdf');
  }

  Future<void> _exportExcel(List<Painting> paintings) async {
    final file = await ExportService.instance.exportExcel(paintings);
    if (!mounted) return;
    await ShareService.instance.shareFile(file.path, text: 'Excel export');
  }

  /// Curates this artwork into the owner's public gallery and shares the
  /// gallery page (published to a public Storage path, or as an HTML file
  /// when the cloud isn't available).
  Future<void> _publicGallery(Painting painting) async {
    final result = await showDialog<_PublicGalleryResult>(
      context: context,
      builder: (context) =>
          _PublicGalleryDialog(included: painting.inPublicGallery),
    );
    if (result == null || !mounted) return;

    if (result.include != painting.inPublicGallery) {
      await PaintingRepository.instance.save(
        painting.copyWith(
          inPublicGallery: result.include,
          needsSync: true,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
    }
    if (!result.share) return;

    final uid = ref.read(authProvider).user?.uid ?? '';
    final curated = PaintingRepository.instance
        .readAll()
        .where((p) => !p.isDeleted && p.inPublicGallery)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Preparing gallery page (${curated.length})…')),
    );

    try {
      final isPro = ref.read(authProvider).isPro;
      final url = await PublicGalleryService.instance.publish(
        curated,
        ownerUid: uid,
        // Pro only: stamp the owner's name + arm view analytics.
        watermark: isPro
            ? (ref.read(authProvider).user?.displayName ?? '')
            : '',
      );
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        await ShareService.instance.shareText(
          'My ArtVault gallery: $url',
          subject: 'My ArtVault gallery',
        );
        if (mounted) {
          await showConfettiCelebration(
            context,
            id: 'gallery-published',
            title: 'Gallery published!',
            message:
                'Your curated page is live. Anyone with the link can '
                'view it until you revoke or expire it.',
            icon: Icons.public,
            iconLabel: 'Link shared',
          );
        }
      } else {
        final file = await PublicGalleryService.instance.writeLocalHtml(
          curated,
        );
        if (!mounted) return;
        await ShareService.instance.shareFile(
          file.path,
          text: 'My ArtVault gallery (offline page)',
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share the gallery: $e')),
      );
    }
  }

  /// Opens the link-management dialog: copy the current link, set an expiry,
  /// or revoke it so the shared page stops resolving.
  Future<void> _manageGalleryLink() async {
    final uid = ref.read(authProvider).user?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to manage your gallery link.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _ManageGalleryLinkDialog(ownerUid: uid),
    );
  }
}

enum _ShareAction { image, withDescription, watermark, qr, pdf }

enum _MoreAction {
  edit,
  delete,
  download,
  print,
  exportPdf,
  exportExcel,
  publicGallery,
  manageGalleryLink,
}

class _ShareSheet extends StatelessWidget {
  final Painting painting;

  const _ShareSheet({required this.painting});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share “${painting.title}”',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              _ShareTarget(
                icon: Icons.image_outlined,
                label: 'Image',
                value: _ShareAction.image,
              ),
              _ShareTarget(
                icon: Icons.notes,
                label: 'Image + text',
                value: _ShareAction.withDescription,
              ),
              _ShareTarget(
                icon: Icons.branding_watermark_outlined,
                label: 'Watermark',
                value: _ShareAction.watermark,
              ),
              _ShareTarget(
                icon: Icons.qr_code_2,
                label: 'QR code',
                value: _ShareAction.qr,
              ),
              _ShareTarget(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                value: _ShareAction.pdf,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Opens the native share sheet — WhatsApp, Instagram, AirDrop & more.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ShareAction value;

  const _ShareTarget({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => Navigator.pop(context, value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final Painting painting;
  final bool canEdit;

  const _TitleBlock({required this.painting, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                painting.title,
                style: AppTheme.display(
                  context,
                  size: context.adaptiveFont(26),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                painting.artistName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Tags wrap onto new lines instead of overflowing the row
              // when the title column is squeezed by the price box.
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  TagChip(
                    label: painting.category.isEmpty
                        ? 'Uncategorized'
                        : painting.category,
                  ),
                  TagChip(
                    label: painting.medium.isEmpty
                        ? 'Medium unknown'
                        : painting.medium,
                  ),
                  if (painting.availability.isNotEmpty)
                    TagChip(
                      label: painting.availability,
                      color: painting.availability == 'Available'
                          ? AppColors.success
                          : painting.availability == 'Sold'
                          ? AppColors.error
                          : AppColors.accent,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (painting.price != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.money(painting.price, currency: painting.currency),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  painting.currency,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Painting painting;

  const _InfoGrid({required this.painting});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (
        Icons.straighten,
        'Dimensions',
        Formatters.dimensions(
          width: painting.width,
          height: painting.height,
          depth: painting.depth,
          unit: painting.dimensionUnit,
        ),
      ),
      (
        Icons.scale,
        'Weight',
        painting.weight != null
            ? '${painting.weight} ${painting.weightUnit}'
            : '—',
      ),
      (
        Icons.category_outlined,
        'Style',
        painting.style.isEmpty ? '—' : painting.style,
      ),
      (
        Icons.location_on_outlined,
        'Location',
        painting.location.isEmpty ? '—' : painting.location,
      ),
      (Icons.event, 'Date created', painting.dateCreated ?? '—'),
      (
        Icons.calendar_today,
        'Added to vault',
        Formatters.date(painting.createdAt),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 3 : 2;
        return Column(
          children: [
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.1,
              children: [
                for (final row in rows)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(row.$1, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                row.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          row.$3,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (painting.lat != null && painting.lng != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // ignore: deprecated_member_use
                    launchUrl(Uri.parse(
                        'https://www.openstreetmap.org/?mlat=${painting.lat}&mlon=${painting.lng}#map=15/${painting.lat}/${painting.lng}'));
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                      '${painting.lat!.toStringAsFixed(4)}, ${painting.lng!.toStringAsFixed(4)} — Open in map'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Palette extends StatelessWidget {
  final List<String> colors;

  const _Palette({required this.colors});

  @override
  Widget build(BuildContext context) {
    // Wrap (not Row): six fixed 44px swatches would overflow narrow screens.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final hex in colors)
          Tooltip(
            message: hex,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ImageUtils.colorFromHex(hex),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AiAnalysisCard extends StatelessWidget {
  final Painting painting;

  const _AiAnalysisCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'AI Analysis',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Metric(
                label: 'Brightness',
                value: Formatters.percent(painting.brightness),
              ),
              _Metric(
                label: 'Contrast',
                value: Formatters.percent(painting.contrast),
              ),
              _Metric(label: 'Orientation', value: painting.orientation),
              _Metric(
                label: 'Complexity',
                value: Formatters.percent(painting.complexity),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 110,
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends ConsumerWidget {
  final String paintingId;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<ArtDocument> onOpen;

  const _DocumentsSection({
    required this.paintingId,
    required this.canEdit,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsForPaintingProvider(paintingId));
    final scheme = Theme.of(context).colorScheme;

    if (docs.isEmpty) {
      return Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'No documents yet. Attach certificates, invoices or provenance.',
              ),
            ),
            if (canEdit)
              IconButton(
                tooltip: 'Add document',
                icon: const Icon(Icons.add),
                color: scheme.primary,
                onPressed: onAdd,
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final doc in docs)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_docIcon(doc.type), color: scheme.primary),
              title: Text(
                doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${doc.type} · ${Formatters.bytes(doc.sizeBytes)}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open document',
                    icon: const Icon(Icons.share_outlined, size: 18),
                    onPressed: () => onOpen(doc),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (action) async {
                        final repo = DocumentRepository.instance;
                        switch (action) {
                          case 'rename':
                            final name = await _promptName(context, doc.name);
                            if (name != null) await repo.rename(doc.id, name);
                          case 'delete':
                            await repo.delete(doc.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add document'),
            ),
          ),
      ],
    );
  }

  static IconData _docIcon(String type) => switch (type) {
    'Certificate' => Icons.workspace_premium_outlined,
    'Invoice' => Icons.receipt_long_outlined,
    'Ownership' => Icons.gavel_outlined,
    'Insurance' => Icons.shield_outlined,
    'Biography' => Icons.article_outlined,
    'Restoration Report' => Icons.healing_outlined,
    'Appraisal' => Icons.stacked_line_chart,
    _ => Icons.description_outlined,
  };

  static Future<String?> _promptName(BuildContext context, String current) {
    // Reuses the shared RenameDocumentDialog, which owns and disposes its
    // TextEditingController; the copy that lived here created a controller
    // and never disposed it (a leak).
    return showDialog<String>(
      context: context,
      builder: (_) => RenameDocumentDialog(initial: current),
    );
  }
}

class _QrCard extends StatelessWidget {
  final Painting painting;

  const _QrCard({required this.painting});

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _QrFullscreenDialog(painting: painting),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          // Tap the code to open it full screen so other devices can scan
          // it easily.
          GestureDetector(
            onTap: () => _openFullscreen(context),
            child: Stack(
              children: [
                QrImageView(
                  data: QrService.payloadFor(
                    painting.id,
                    title: painting.title,
                    artistName: painting.artistName,
                    price: painting.price,
                    currency: painting.currency,
                    description: painting.description,
                    imageUrl: painting.coverImageUrl,
                  ),
                  size: 100,
                  version: QrVersions.auto,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: scheme.primary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: scheme.primary,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.zoom_out_map,
                      size: 13,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan to view',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tap the code to view it full screen, then point any camera at it to open the artwork in ArtVault.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Share QR',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ShareService.instance.shareQr(painting),
          ),
        ],
      ),
    );
  }
}

/// Full-screen QR viewer: renders the code large on a white card (dark
/// modules) so any other device can scan it easily, with the artwork title,
/// artist and price underneath.
class _QrFullscreenDialog extends StatelessWidget {
  final Painting painting;

  const _QrFullscreenDialog({required this.painting});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final qrSize = math.min(
      size.width - 80,
      math.min(size.height * 0.46, 380.0),
    );
    final payload = QrService.payloadFor(
      painting.id,
      title: painting.title,
      artistName: painting.artistName,
      price: painting.price,
      currency: painting.currency,
      description: painting.description,
      imageUrl: painting.coverImageUrl,
    );

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // White card + near-black modules: maximum contrast for
                    // phone cameras to lock onto.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: payload,
                        size: qrSize,
                        version: QrVersions.auto,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      painting.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      painting.artistName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                    ),
                    if (painting.price != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          Formatters.money(
                            painting.price,
                            currency: painting.currency,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Point the camera of another device at this code to open '
                      'the artwork in ArtVault.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              ShareService.instance.shareQr(painting),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share QR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Condition history for a painting — latest report plus an add button.
/// Shows the newest report's photo, condition, notes and a “last inspected”
/// reminder that turns amber when the piece is overdue for re-inspection.
class _ConditionSection extends ConsumerWidget {
  final String paintingId;
  final bool canEdit;

  const _ConditionSection({required this.paintingId, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(conditionReportsForPaintingProvider(paintingId));
    final scheme = Theme.of(context).colorScheme;

    if (reports.isEmpty) {
      return Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.healing_outlined,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'No condition reports yet. Record the physical state and last inspection.',
              ),
            ),
            if (canEdit)
              IconButton(
                tooltip: 'Add condition report',
                icon: const Icon(Icons.add),
                color: scheme.primary,
                onPressed: () => _openAddDialog(context),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final report in reports.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              leading: _ReportThumb(report: report),
              title: Row(
                children: [
                  _ConditionChip(condition: report.condition),
                  const Spacer(),
                  Text(
                    _lastInspected(report.inspectedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: _overdue(report.inspectedAt)
                          ? const Color(0xFFE0A100)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              subtitle: report.notes.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        report.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => _showReport(context, report),
            ),
          ),
        if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openAddDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add report'),
            ),
          ),
      ],
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final draft = await showDialog<ConditionReportDraft>(
      context: context,
      builder: (context) => ConditionReportDialog(paintingId: paintingId),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ConditionReportRepository.instance.add(
        paintingId: paintingId,
        condition: draft.condition,
        notes: draft.notes,
        inspectedAt: draft.inspectedAt,
        photo: draft.photo,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Condition report saved')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the condition report.')),
      );
    }
  }

  Future<void> _showReport(BuildContext context, ConditionReport report) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _ConditionReportView(report: report, canDelete: canEdit),
    );
  }

  static String _lastInspected(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inDays < 1) return 'Inspected today';
    if (diff.inDays < 30) return 'Inspected ${diff.inDays} days ago';
    final months = diff.inDays ~/ 30;
    if (months < 12) return 'Inspected $months months ago';
    final years = months ~/ 12;
    return 'Inspected $years year${years == 1 ? '' : 's'} ago';
  }

  /// Re-inspection is due once a report is more than 18 months old.
  static bool _overdue(DateTime at) =>
      DateTime.now().difference(at).inDays ~/ 30 >= 18;
}

class _ReportThumb extends StatelessWidget {
  final ConditionReport report;

  const _ReportThumb({required this.report});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: 56,
        height: 56,
        child: report.photoUrl.isNotEmpty || report.photoPath.isNotEmpty
            ? ArtImage(
                path: report.photoPath.isEmpty ? null : report.photoPath,
                url: report.photoUrl.isEmpty ? null : report.photoUrl,
                fit: BoxFit.cover,
              )
            : Container(
                color: scheme.primary.withValues(alpha: 0.08),
                child: Icon(
                  Icons.healing_outlined,
                  color: scheme.primary.withValues(alpha: 0.6),
                ),
              ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String condition;

  const _ConditionChip({required this.condition});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(condition);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        condition,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Color _colorFor(String condition) => switch (condition) {
    'Excellent' => const Color(0xFF2E9E5B),
    'Good' => const Color(0xFF3E8E41),
    'Fair' => const Color(0xFFE0A100),
    'Poor' => const Color(0xFFE67E22),
    _ => const Color(0xFFD64550),
  };
}

class _ConditionReportView extends StatelessWidget {
  final ConditionReport report;
  final bool canDelete;

  const _ConditionReportView({required this.report, required this.canDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = report.photoUrl.isNotEmpty || report.photoPath.isNotEmpty;
    return AlertDialog(
      title: Row(
        children: [
          _ConditionChip(condition: report.condition),
          const Spacer(),
          Text(
            Formatters.date(report.inspectedAt),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ArtImage(
                    path: report.photoPath.isEmpty ? null : report.photoPath,
                    url: report.photoUrl.isEmpty ? null : report.photoUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (hasPhoto) const SizedBox(height: AppSpacing.md),
            if (report.notes.isNotEmpty)
              Text(report.notes, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        if (canDelete)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await ConditionReportRepository.instance.delete(report.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Expiry presets offered when managing a gallery link.
const _expiryPresets = <({String label, Duration? duration})>[
  (label: 'Never expires', duration: null),
  (label: '1 day', duration: Duration(days: 1)),
  (label: '7 days', duration: Duration(days: 7)),
  (label: '30 days', duration: Duration(days: 30)),
  (label: '1 year', duration: Duration(days: 365)),
];

/// Lets the owner inspect their published gallery link, copy it, set an
/// expiry, or revoke it so the shared page stops resolving for everyone
/// holding the URL.
class _ManageGalleryLinkDialog extends ConsumerStatefulWidget {
  final String ownerUid;

  const _ManageGalleryLinkDialog({required this.ownerUid});

  @override
  ConsumerState<_ManageGalleryLinkDialog> createState() =>
      _ManageGalleryLinkDialogState();
}

class _ManageGalleryLinkDialogState
    extends ConsumerState<_ManageGalleryLinkDialog> {
  PublicGalleryStatus? _status;
  bool _loading = true;
  bool _busy = false;
  late bool _watermark;

  @override
  void initState() {
    super.initState();
    _watermark = ref.read(authProvider).isPro;
    _load();
  }

  Future<void> _load() async {
    final status = await PublicGalleryService.instance.status(widget.ownerUid);
    if (!mounted) return;
    setState(() {
      _status = status;
      if (status != null && status.watermark.isNotEmpty) _watermark = true;
      _loading = false;
    });
  }

  /// Publishes a fresh link (used when none exists or the old one was
  /// revoked), then shares it.
  Future<void> _publishAndShare() async {
    final curated = PaintingRepository.instance
        .readAll()
        .where((p) => !p.isDeleted && p.inPublicGallery)
        .toList();
    final isPro = ref.read(authProvider).isPro;
    setState(() => _busy = true);
    String? url;
    try {
      url = await PublicGalleryService.instance.publish(
        curated,
        ownerUid: widget.ownerUid,
        // Pro only: stamp the owner's name + arm view analytics.
        watermark: isPro && _watermark
            ? (ref.read(authProvider).user?.displayName ?? '')
            : '',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      final file = await PublicGalleryService.instance.writeLocalHtml(curated);
      if (!mounted) return;
      await ShareService.instance.shareFile(
        file.path,
        text: 'My ArtVault gallery (offline page)',
      );
      return;
    }
    await _load();
    if (!mounted) return;
    await ShareService.instance.shareText(
      'My ArtVault gallery: $url',
      subject: 'My ArtVault gallery',
    );
    if (mounted) {
      await showConfettiCelebration(
        context,
        id: 'gallery-published',
        title: 'Gallery published!',
        message:
            'Your curated page is live. Anyone with the link can '
            'view it until you revoke or expire it.',
        icon: Icons.public,
        iconLabel: 'Link shared',
      );
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    // A soft success haptic + green flash so the copy lands physically.
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gallery link copied'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _applyExpiry(Duration? choice) async {
    setState(() => _busy = true);
    final expiresAt = choice == null ? null : DateTime.now().add(choice);
    await PublicGalleryService.instance.setExpiry(widget.ownerUid, expiresAt);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice == null
              ? 'Gallery link no longer expires'
              : 'Gallery link will stop working in ${_describeDuration(choice)}',
        ),
      ),
    );
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke gallery link?'),
        content: const Text(
          'The shared page will stop resolving immediately for anyone '
          'holding the link, and the published page will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await PublicGalleryService.instance.revoke(widget.ownerUid);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Gallery link revoked')));
  }

  static String _describeDuration(Duration d) {
    if (d.inDays >= 365) return '1 year';
    if (d.inDays >= 30) return '${d.inDays ~/ 30} months';
    if (d.inDays >= 7) return '${d.inDays ~/ 7} weeks';
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'}'.replaceFirst(
      '1 days',
      '1 day',
    );
  }

  /// The preset matching the current expiry (nearest within 2h), so the
  /// dropdown reflects the live link state.
  Duration? get _selectedExpiry {
    final exp = _status?.expiresAt;
    if (exp == null) return null;
    final remaining = exp.difference(DateTime.now());
    Duration? best;
    var bestDiff = const Duration(hours: 2);
    for (final preset in _expiryPresets) {
      final d = preset.duration;
      if (d == null) continue;
      final diff = (remaining - d).abs();
      if (diff <= bestDiff) {
        bestDiff = diff;
        best = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Manage gallery link'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    final status = _status;
    if (status == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No gallery link published yet. Publish one to get a shareable '
            'page you can expire or revoke at any time.',
            style: TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _publishAndShare,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Publish & share'),
          ),
        ],
      );
    }

    final isPro = ref.read(authProvider).isPro;
    final now = DateTime.now();
    // A link whose expiry has passed is still `active` in its document, but
    // the storage rules stop serving it — surface it as expired.
    final expired =
        status.active &&
        status.expiresAt != null &&
        !status.expiresAt!.isAfter(now);
    final active = status.active && !expired && status.url != null;
    final expiringSoon =
        active &&
        status.expiresAt != null &&
        status.expiresAt!.difference(now) <= const Duration(days: 7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expired) ...[
          Row(
            children: [
              Icon(Icons.timer_off, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              const Text('Link expired', style: TextStyle(fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This link expired on ${Formatters.date(status.expiresAt)} and '
            'no longer resolves. Publish a new link to share the gallery '
            'again.',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _publishAndShare,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Publish new link'),
          ),
        ] else if (!active) ...[
          const Text(
            'This link was revoked and no longer resolves. Publish a new '
            'link to share the gallery again.',
            style: TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _publishAndShare,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Publish new link'),
          ),
        ] else ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text('Link is active', style: TextStyle(fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              status.url!,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _copyLink(status.url!),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => ShareService.instance.shareText(
                        'My ArtVault gallery: ${status.url}',
                        subject: 'My ArtVault gallery',
                      ),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share'),
              ),
            ],
          ),
          if (expiringSoon) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.hourglass_top, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expires in ${_describeDuration(status.expiresAt!.difference(DateTime.now()))}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!isPro) ...[
            Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free plan: links expire within 30 days. Pro links can live up to a year.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Text(
                'Expiry',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              DropdownButton<Duration?>(
                value: _selectedExpiry,
                items: [
                  for (final preset in _expiryPresets)
                    if (isPro ||
                        preset.duration == null ||
                        (preset.duration != null &&
                            preset.duration! <= ProLimits.freeMaxExpiry))
                      DropdownMenuItem<Duration?>(
                        value: preset.duration,
                        child: Text(preset.label),
                      ),
                ],
                onChanged: _busy ? null : (v) => _applyExpiry(v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            status.expiresAt == null
                ? 'Current: never expires'
                : 'Current: expires ${Formatters.date(status.expiresAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: expiringSoon
                  ? AppColors.warning
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isPro) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _watermark,
              onChanged: _busy ? null : (v) => setState(() => _watermark = v),
              title: const Text('Watermark images'),
              subtitle: const Text(
                'Stamp your name across the page and track views',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_watermark)
              OutlinedButton.icon(
                onPressed: _busy ? null : _publishAndShare,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Republish with watermark'),
              ),
          ],
          if (status.views != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${status.views} view${status.views == 1 ? '' : 's'} of this link',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : _revoke,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('Revoke link'),
          ),
        ],
      ],
    );
  }
}

class _PublicGalleryResult {
  final bool include;
  final bool share;

  const _PublicGalleryResult({required this.include, required this.share});
}

/// Curates one artwork into the public gallery. Stateless form: pops a
/// [_PublicGalleryResult] (include + whether to share now).
class _PublicGalleryDialog extends StatefulWidget {
  final bool included;

  const _PublicGalleryDialog({required this.included});

  @override
  State<_PublicGalleryDialog> createState() => _PublicGalleryDialogState();
}

class _PublicGalleryDialogState extends State<_PublicGalleryDialog> {
  late bool _included = widget.included;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Public gallery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Artworks included here appear on a shareable gallery page. '
            'Title, artist, medium, year and location are shown — price is '
            'never included.',
            style: TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _included,
            title: const Text('Include in public gallery'),
            subtitle: const Text('Curate this artwork into the page'),
            onChanged: (v) => setState(() => _included = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _PublicGalleryResult(include: _included, share: true),
          ),
          icon: const Icon(Icons.link, size: 18),
          label: const Text('Share gallery link'),
        ),
      ],
    );
  }
}
