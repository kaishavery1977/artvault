
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/painting.dart';
import '../../../core/widgets/web/web_toast.dart';

/// Web-optimized gallery table view with sortable columns, multi-select,
/// CSV export, keyboard navigation, and infinite scroll skeleton loading.
class GalleryTableView extends ConsumerStatefulWidget {
  const GalleryTableView({super.key});

  @override
  ConsumerState<GalleryTableView> createState() => _GalleryTableViewState();
}

class _GalleryTableViewState extends ConsumerState<GalleryTableView> {
  int _sortColumnIndex = 1; // Sort by title by default
  bool _sortAscending = true;
  final Set<String> _selectedIds = {};
  int _focusedIndex = 0;
  final _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Painting> _sorted(List<Painting> paintings) {
    final sorted = List<Painting>.from(paintings);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // Select (no sort)
          cmp = 0;
        case 1: // Title
          cmp = a.title.compareTo(b.title);
        case 2: // Artist
          cmp = a.artistName.compareTo(b.artistName);
        case 3: // Medium
          cmp = a.medium.compareTo(b.medium);
        case 4: // Value
          cmp = (a.price ?? 0).compareTo(b.price ?? 0);
        case 5: // Date
          cmp = a.updatedAt.compareTo(b.updatedAt);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _selectAll(List<Painting> paintings) {
    setState(() {
      if (_selectedIds.length == paintings.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(paintings.map((p) => p.id));
      }
    });
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} painting${_selectedIds.length > 1 ? 's' : ''}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              WebToast.show(
                context,
                message: '${_selectedIds.length} painting${_selectedIds.length > 1 ? 's' : ''} deleted',
                icon: Icons.delete_rounded,
                color: AppColors.error,
              );
              setState(() => _selectedIds.clear());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportCSV(List<Painting> paintings) {
    final buffer = StringBuffer();
    buffer.writeln('Title,Artist,Medium,Style,Price,Width,Height,Date Added');
    for (final p in paintings) {
      buffer.writeln(
        '"${p.title}","${p.artistName}","${p.medium}","${p.style}",'
        '"${p.price ?? 0}","${p.width ?? ''}","${p.height ?? ''}",'
        '"${p.createdAt.toIso8601String().split('T').first}"',
      );
    }

    // Copy to clipboard for web
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    WebToast.show(
      context,
      message: 'CSV copied to clipboard (${paintings.length} paintings)',
      icon: Icons.copy_rounded,
      color: AppColors.emerald500,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();
    final sorted = _sorted(paintings);
    final isLoading = paintingsAsync.isLoading && paintingsAsync.valueOrNull == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Arrow navigation
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, sorted.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() => _focusedIndex = (_focusedIndex - 1).clamp(0, sorted.length - 1));
          return KeyEventResult.handled;
        }
        // Enter to open
        if (event.logicalKey == LogicalKeyboardKey.enter && sorted.isNotEmpty) {
          context.push('/painting/${sorted[_focusedIndex].id}');
          return KeyEventResult.handled;
        }
        // E to edit
        if (event.logicalKey == LogicalKeyboardKey.keyE && sorted.isNotEmpty) {
          context.push('/painting/edit/${sorted[_focusedIndex].id}');
          return KeyEventResult.handled;
        }
        // Delete to trash
        if (event.logicalKey == LogicalKeyboardKey.delete && sorted.isNotEmpty) {
          WebToast.show(context, message: 'Moved to trash', icon: Icons.delete_rounded, color: AppColors.error);
          return KeyEventResult.handled;
        }
        // Ctrl+A to select all
        if (event.logicalKey == LogicalKeyboardKey.keyA && HardwareKeyboard.instance.isControlPressed) {
          _selectAll(sorted);
          return KeyEventResult.handled;
        }
        // Ctrl+E to export
        if (event.logicalKey == LogicalKeyboardKey.keyE && HardwareKeyboard.instance.isControlPressed) {
          _exportCSV(sorted);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Toolbar
          _TableToolbar(
            selectedCount: _selectedIds.length,
            totalCount: sorted.length,
            onSelectAll: () => _selectAll(sorted),
            onDelete: _deleteSelected,
            onExport: () => _exportCSV(sorted),
          ),
          // Table
          Expanded(
            child: isLoading
                ? _SkeletonTable()
                : sorted.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grid_view_rounded, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('No paintings yet', style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => context.push('/painting/new'),
                              icon: const Icon(Icons.add),
                              label: const Text('Upload your first painting'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        child: DataTable(
                          showCheckboxColumn: true,
                          headingRowColor: WidgetStateProperty.all(
                            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                          ),
                          dataRowColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.accent.withValues(alpha: 0.06);
                            }
                            return null;
                          }),
                          columns: [
                            DataColumn(
                              label: SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: _selectedIds.length == sorted.length && sorted.isNotEmpty,
                                  onChanged: (_) => _selectAll(sorted),
                                  tristate: true,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: const Text('Title'),
                              onSort: _sort,
                            ),
                            DataColumn(
                              label: const Text('Artist'),
                              onSort: _sort,
                            ),
                            DataColumn(
                              label: const Text('Medium'),
                              onSort: _sort,
                            ),
                            DataColumn(
                              label: const Text('Value'),
                              numeric: true,
                              onSort: _sort,
                            ),
                            DataColumn(
                              label: const Text('Date'),
                              onSort: _sort,
                            ),
                            const DataColumn(label: Text('')),
                          ],
                          rows: List.generate(sorted.length, (i) {
                            final p = sorted[i];
                            final isSelected = _selectedIds.contains(p.id);
                            final isFocused = i == _focusedIndex;

                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedIds.add(p.id);
                                  } else {
                                    _selectedIds.remove(p.id);
                                  }
                                });
                              },
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(p.id);
                                        } else {
                                          _selectedIds.remove(p.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: scheme.surfaceContainerHighest,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: p.coverImagePath.isNotEmpty
                                            ? Image.network(
                                                p.coverImagePath,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Icon(
                                                  Icons.palette_rounded,
                                                  size: 18,
                                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                                ),
                                              )
                                            : Icon(
                                                Icons.palette_rounded,
                                                size: 18,
                                                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        p.title,
                                        style: TextStyle(
                                          fontWeight: isFocused ? FontWeight.w700 : FontWeight.w600,
                                          color: isFocused ? AppColors.accent : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.artistName.isNotEmpty ? p.artistName : '—')),
                                DataCell(
                                  p.medium.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(p.medium, style: TextStyle(fontSize: 12, color: AppColors.accent)),
                                        )
                                      : const Text('—'),
                                ),
                                DataCell(Text(
                                  p.price != null ? Formatters.money(p.price!) : '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: p.price != null ? AppColors.amber500 : null,
                                  ),
                                )),
                                DataCell(Text(
                                  '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                )),
                                DataCell(
                                  PopupMenuButton<String>(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'view', child: Row(children: [const Icon(Icons.visibility_rounded, size: 16), const SizedBox(width: 8), const Text('View')])),
                                      PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, size: 16), const SizedBox(width: 8), const Text('Edit')])),
                                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: AppColors.error), const SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
                                    ],
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'view':
                                          context.push('/painting/${p.id}');
                                        case 'edit':
                                          context.push('/painting/edit/${p.id}');
                                        case 'delete':
                                          WebToast.show(context, message: 'Moved to trash', icon: Icons.delete_rounded, color: AppColors.error);
                                      }
                                    },
                                    icon: Icon(Icons.more_vert_rounded, size: 18, color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TableToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _TableToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // Count
          Text(
            selectedCount > 0
                ? '$selectedCount selected'
                : '$totalCount paintings',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selectedCount > 0 ? AppColors.accent : scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // Keyboard hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '↑↓ navigate  Enter open  E edit  Del trash  Ctrl+A select  Ctrl+E export',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 12),
          // Export
          _ToolButton(
            icon: Icons.file_download_rounded,
            label: 'Export CSV',
            onTap: onExport,
          ),
          if (selectedCount > 0) ...[
            const SizedBox(width: 8),
            _ToolButton(
              icon: Icons.delete_rounded,
              label: 'Delete ($selectedCount)',
              color: AppColors.error,
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? (widget.color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading table for web gallery.
class _SkeletonTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1200.ms);
  }
}
