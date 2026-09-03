import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/painting.dart';
import '../painting/painting_detail_screen.dart';

/// Resizable split panel view for gallery on web.
/// Left: scrollable painting list. Right: selected painting detail.
/// Divider is draggable to resize panels.
class SplitPanelView extends ConsumerStatefulWidget {
  const SplitPanelView({super.key});

  @override
  ConsumerState<SplitPanelView> createState() => _SplitPanelViewState();
}

class _SplitPanelViewState extends ConsumerState<SplitPanelView> {
  String? _selectedId;
  double _splitRatio = 0.35; // 35% list, 65% detail
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings =
        (paintingsAsync.valueOrNull ?? const <Painting>[])
            .where((p) => !p.isDeleted)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final selected = _selectedId != null
        ? paintings.where((p) => p.id == _selectedId).firstOrNull
        : null;

    // Auto-select first painting if none selected
    if (_selectedId == null && paintings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = paintings.first.id);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Left panel: painting list
        SizedBox(
          width: MediaQuery.of(context).size.width * _splitRatio,
          child: _PaintingList(
            paintings: paintings,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
          ),
        ),
        // Draggable divider
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() => _isDragging = true),
            onHorizontalDragUpdate: (details) {
              final totalWidth = MediaQuery.of(context).size.width;
              final newRatio = (details.localPosition.dx / totalWidth).clamp(
                0.2,
                0.6,
              );
              setState(() => _splitRatio = newRatio);
            },
            onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: _isDragging ? 4 : 1,
              color: _isDragging
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.08,
                    ),
            ),
          ),
        ),
        // Right panel: detail
        Expanded(
          child: selected != null
              ? PaintingDetailScreen(paintingId: selected.id)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 48,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a painting to view details',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PaintingList extends StatelessWidget {
  final List<Painting> paintings;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _PaintingList({
    required this.paintings,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: paintings.isEmpty
          ? Center(
              child: Text(
                'No paintings',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: paintings.length,
              itemBuilder: (_, i) {
                final p = paintings[i];
                final isSelected = p.id == selectedId;

                return _PaintingListTile(
                  painting: p,
                  isSelected: isSelected,
                  onTap: () => onSelect(p.id),
                );
              },
            ),
    );
  }
}

class _PaintingListTile extends StatefulWidget {
  final Painting painting;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaintingListTile({
    required this.painting,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PaintingListTile> createState() => _PaintingListTileState();
}

class _PaintingListTileState extends State<_PaintingListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.painting;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent.withValues(alpha: 0.1)
                : _hovered
                ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    width: 0.8,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 40,
                height: 40,
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
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: widget.isSelected ? AppColors.accent : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.artistName.isNotEmpty ? p.artistName : 'Unknown artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Price
              if (p.price != null)
                Text(
                  '\$${p.price!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
