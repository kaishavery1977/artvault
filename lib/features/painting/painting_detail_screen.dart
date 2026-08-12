import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/export_service.dart';
import '../../core/services/qr_service.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import 'painting_lightbox_screen.dart';
import '../../data/models/art_document.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/painting_repository.dart';
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
    final related = (ref.watch(paintingsProvider).valueOrNull ?? const [])
        .where(
          (p) =>
              p.id != widget.paintingId &&
              !p.isDeleted &&
              (p.artistName == painting?.artistName ||
                  p.category == painting?.category),
        )
        .take(6)
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

    final canEdit = ref.watch(authProvider).canEdit;
    final images = painting.images.isEmpty
        ? <String>[painting.coverImagePath]
        : painting.images;
    final urls = painting.imageUrls.isEmpty
        ? <String>[painting.coverImageUrl]
        : painting.imageUrls;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
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
                children: [
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
                        for (final t in {...painting.tags, ...painting.aiTags})
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
                  SectionHeader(title: 'QR code'),
                  _QrCard(painting: painting),
                  if (related.isNotEmpty) ...[
                    SectionHeader(title: 'Related paintings'),
                    SizedBox(
                      height: 190,
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
}

enum _ShareAction { image, withDescription, watermark, qr, pdf }

enum _MoreAction { edit, delete, download, print, exportPdf, exportExcel }

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
              ).colorScheme.onSurface.withValues(alpha: 0.5),
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
              Text(painting.title, style: AppTheme.display(context, size: 26)),
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
                    color: scheme.onSurface.withValues(alpha: 0.5),
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
        return GridView.count(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          row.$1,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            row.$2,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      row.$3,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
                color: scheme.onSurface.withValues(alpha: 0.55),
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

  static Future<String?> _promptName(
    BuildContext context,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return name;
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
                    color: scheme.onSurface.withValues(alpha: 0.55),
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
