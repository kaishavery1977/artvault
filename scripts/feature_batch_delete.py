import pathlib

p = pathlib.Path(r'lib/features/gallery/gallery_screen.dart')
c = p.read_text(encoding='utf-8')

# 1. Add import for PaintingRepository (for batch delete)
old_import = "import '../../data/models/painting.dart';"
new_import = """import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';"""
c = c.replace(old_import, new_import)

# 2. Add selection state fields to _GalleryScreenState
old_fields = """  final ScrollController _controller = ScrollController();
  int _visibleCount = 18;"""

new_fields = """  final ScrollController _controller = ScrollController();
  int _visibleCount = 18;

  // Batch delete: long-press to enter select mode.
  bool _selectMode = false;
  final Set<String> _selectedIds = {};"""

c = c.replace(old_fields, new_fields)

# 3. Add toggle and batch delete methods after _filter
old_filter_end = """    return list;
  }

  @override
  Widget build(BuildContext context) {"""

new_filter_end = """    return list;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectMode(String id) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ids = Set<String>.from(_selectedIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count painting${count > 1 ? 's' : ''}?'),
        content: Text(
          '$count painting${count > 1 ? 's' : ''} will be moved to Trash. '
          'You can restore them from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final id in ids) {
      await PaintingRepository.instance.delete(id);
    }

    _exitSelectMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count painting${count > 1 ? 's' : ''} moved to trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final id in ids) {
                await PaintingRepository.instance.restore(id);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {"""

c = c.replace(old_filter_end, new_filter_end)

# 4. Update the Scaffold to include a batch delete FAB when in select mode
# and add willPopScope for back button exit
old_scaffold = """    return Scaffold(
      body: RefreshIndicator("""

new_scaffold = """    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
      appBar: _selectMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      final all = _filter(
                        ref.read(paintingsProvider).valueOrNull ?? const [],
                      );
                      _selectedIds.addAll(all.map((p) => p.id));
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _batchDelete,
                ),
              ],
            )
          : null,
      floatingActionButton: _selectMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _batchDelete,
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete ${_selectedIds.length}'),
            )
          : null,
      body: RefreshIndicator("""

c = c.replace(old_scaffold, new_scaffold)

# 5. Close the extra PopScope bracket at the end
old_end = """      ),
      ),
    );
  }
}"""

new_end = """      ),
      ),
      ),
    );
  }
}"""

c = c.replace(old_end, new_end)

# 6. Update PaintingGridCard usage to pass select mode callbacks
# Replace all PaintingGridCard occurrences in the build method
c = c.replace(
    """                    (context, i) => PaintingGridCard(
                      painting: visible[i],
                      heroTag: 'painting-${visible[i].id}',
                      staggerIndex: i,
                    ),""",
    """                    (context, i) => PaintingGridCard(
                      painting: visible[i],
                      heroTag: 'painting-${visible[i].id}',
                      staggerIndex: i,
                      selectMode: _selectMode,
                      selected: _selectedIds.contains(visible[i].id),
                      onSelect: () => _toggleSelect(visible[i].id),
                      onLongPress: () => _enterSelectMode(visible[i].id),
                    ),"""
)

c = c.replace(
    """                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PaintingListTile(painting: visible[i]),
                    ),""",
    """                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PaintingListTile(
                        painting: visible[i],
                        selectMode: _selectMode,
                        selected: _selectedIds.contains(visible[i].id),
                        onSelect: () => _toggleSelect(visible[i].id),
                        onLongPress: () => _enterSelectMode(visible[i].id),
                      ),
                    ),"""
)

p.write_text(c, encoding='utf-8')
print("Gallery: added batch delete multi-select mode")
