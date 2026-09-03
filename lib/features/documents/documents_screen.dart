import 'package:artvault/utils/io_shim.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/pro_limits.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../features/pro/pro_celebration.dart';
import '../../features/pro/upgrade_prompt.dart';
import '../../data/models/art_document.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/document_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);
    final docs = (docsAsync.valueOrNull ?? const <ArtDocument>[])
        .where((d) => !d.isDeleted)
        .toList();
    final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));

    String titleFor(String paintingId) {
      for (final p in paintings) {
        if (p.id == paintingId) return p.title;
      }
      return '—';
    }

    return Scaffold(
      body: docs.isEmpty
          ? const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No documents yet',
              subtitle:
                  'Certificates, invoices and provenance files will appear here.',
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(documentsProvider);
                ref.invalidate(paintingsProvider);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.adaptiveSpace(AppSpacing.md),
                        AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
                        context.adaptiveSpace(AppSpacing.md),
                        AppSpacing.sm,
                      ),
                      child: Text(
                        'Documents',
                        style: AppTheme.display(
                          context,
                          size: context.adaptiveFont(28),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: AppSpacing.screenPadding,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final doc = docs[i];
                        final tile = _DocumentTile(
                          doc: doc,
                          paintingTitle: titleFor(doc.paintingId),
                          canEdit: canEdit,
                          onOpen: () async {
                            final file = await DocumentRepository.instance
                                .openFile(doc);
                            if (file != null) {
                              await ShareService.instance.shareFile(
                                file.path,
                                text: doc.name,
                              );
                            }
                          },
                          onTapPainting: () {
                            if (doc.paintingId.isNotEmpty) {
                              context.push('/painting/${doc.paintingId}');
                            }
                          },
                        );
                        return revealListItem(
                          tile,
                          i,
                          key: ValueKey(doc.id),
                          context: context,
                        );
                      }, childCount: docs.length),
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
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addDocument(context, ref, paintings),
              icon: const Icon(Icons.upload_file),
              label: const Text('Add document'),
            )
          : null,
    );
  }

  static Future<void> _addDocument(
    BuildContext context,
    WidgetRef ref,
    List<Painting> paintings,
  ) async {
    // Free-tier capacity gate for new documents.
    if (!ref.read(authProvider).isPro) {
      final active = DocumentRepository.instance
          .readAll()
          .where((d) => !d.isDeleted)
          .length;
      if (active >= ProLimits.freeDocuments) {
        await showUpgradePrompt(
          context,
          feature: 'Adding more than ${ProLimits.freeDocuments} documents',
        );
        return;
      }
    }

    final painting = await _pickPainting(context, paintings);
    if (painting == null) return;
    if (!context.mounted) return;
    final type = await _pickType(context);
    if (type == null) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return;

    // Free-tier storage gate: document files beyond 100 MB need Pro.
    if (!ref.read(authProvider).isPro) {
      final usage = ref.read(storageUsageProvider).valueOrNull;
      final current = usage?.countedBytes ?? 0;
      if (current + await File(path).length() > ProLimits.freeStorageBytes) {
        if (context.mounted) {
          await showUpgradePrompt(
            context,
            feature:
                'Storing more than ${ProLimits.freeStorageBytes ~/ (1024 * 1024)} MB '
                'of documents',
          );
        }
        return;
      }
    }

    await DocumentRepository.instance.add(
      paintingId: painting.id,
      type: type,
      name: file.name,
      file: File(path),
    );
    if (context.mounted) {
      // Every new document celebrates (replay skips the cooldown so adding
      // several documents in a row all fire confetti).
      await showConfettiCelebration(
        context,
        id: 'document-added',
        title: 'Document added!',
        message: '\u201c${file.name}\u201d is attached to ${painting.title}.',
        icon: Icons.description,
        iconLabel: 'Saved',
        replay: true,
        celebratory: true,
      );
    }
  }

  static Future<Painting?> _pickPainting(
    BuildContext context,
    List<Painting> paintings,
  ) async {
    if (paintings.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No paintings yet'),
          content: const Text('Add a painting before attaching documents.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }
    return showModalBottomSheet<Painting>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: paintings.length,
          itemBuilder: (context, i) {
            final p = paintings[i];
            return ListTile(
              leading: const Icon(Icons.brush),
              title: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(p.artistName),
              onTap: () => Navigator.pop(context, p),
            );
          },
        ),
      ),
    );
  }

  static Future<String?> _pickType(BuildContext context) {
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
}

class _DocumentTile extends ConsumerWidget {
  final ArtDocument doc;
  final String paintingTitle;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onTapPainting;

  const _DocumentTile({
    required this.doc,
    required this.paintingTitle,
    required this.canEdit,
    required this.onOpen,
    required this.onTapPainting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon(doc.type), color: scheme.primary, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (paintingTitle == 'Unknown artwork' && doc.paintingId.isNotEmpty)
              Tooltip(
                message: 'Unlinked — painting deleted',
                child: Icon(Icons.link_off, size: 16, color: scheme.error),
              ),
          ],
        ),
        subtitle: Text(
          '${doc.type} · ${Formatters.bytes(doc.sizeBytes)} · ${Formatters.date(doc.createdAt)}${paintingTitle == 'Unknown artwork' && doc.paintingId.isNotEmpty ? ' · Unlinked' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined, size: 18),
              onPressed: onOpen,
            ),
            IconButton(
              tooltip: 'View painting',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: onTapPainting,
            ),
            if (canEdit)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (action) async {
                  final repo = DocumentRepository.instance;
                  switch (action) {
                    case 'rename':
                      final name = await showDialog<String>(
                        context: context,
                        // The dialog owns its TextEditingController and
                        // disposes it only when the route fully unmounts.
                        builder: (_) => RenameDocumentDialog(initial: doc.name),
                      );
                      if (name != null && name.isNotEmpty) {
                        await repo.rename(doc.id, name);
                      }
                    case 'delete':
                      await repo.delete(doc.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('"${doc.name}" deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => repo.restore(doc.id),
                              ),
                            ),
                          );
                      }
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
    );
  }

  static IconData _icon(String type) => switch (type) {
    'Certificate' => Icons.workspace_premium_outlined,
    'Invoice' => Icons.receipt_long_outlined,
    'Ownership' => Icons.gavel_outlined,
    'Insurance' => Icons.shield_outlined,
    'Biography' => Icons.article_outlined,
    'Restoration Report' => Icons.healing_outlined,
    'Appraisal' => Icons.stacked_line_chart,
    _ => Icons.description_outlined,
  };
}

/// Rename-document dialog. Owns its [TextEditingController] and disposes it
/// only when the route fully unmounts (after the exit transition) — disposing
/// it at call site would crash the frame while the dialog is still animating
/// out, exactly like the passcode dialogs did.
/// Rename-in-place dialog for a vault document.
///
/// Owns its [TextEditingController] and disposes it only when the route fully
/// unmounts (after the exit transition) — the early-dispose variant crashed
/// the frame while the dialog was still animating out. Pops with the trimmed
/// name on Save, `null` on Cancel.
class RenameDocumentDialog extends StatefulWidget {
  final String initial;

  const RenameDocumentDialog({super.key, required this.initial});

  @override
  State<RenameDocumentDialog> createState() => _RenameDocumentDialogState();
}

class _RenameDocumentDialogState extends State<RenameDocumentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename document'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
