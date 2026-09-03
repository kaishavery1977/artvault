import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'gallery_table_view.dart';
import 'split_panel_view.dart';
import 'package:go_router/go_router.dart';

import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';
import 'painting_card.dart';

enum GalleryView { grid, list, masonry, table, split }

enum GallerySort { newest, oldest, title, artist, priceHigh, priceLow }

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  // Grid is the premium browse default everywhere (table/split remain one
  // tap away in the view switcher). The previous web default of the dense
  // table clashed with the redesigned visual-first shell.
  GalleryView _view = GalleryView.grid;
  GallerySort _sort = GallerySort.newest;
  String? _category;
  bool _favoritesOnly = false;
  final ScrollController _controller = ScrollController();
  int _visibleCount = 18;

  // Batch delete: long-press to enter select mode.
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >
          _controller.position.maxScrollExtent - 400) {
        setState(() => _visibleCount += 18);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra == 'favorites') setState(() => _favoritesOnly = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Painting> _filter(List<Painting> all) {
    var list = all.where((p) => !p.isDeleted).toList();
    if (_favoritesOnly) list = list.where((p) => p.isFavorite).toList();
    if (_category != null) {
      list = list.where((p) => p.category == _category).toList();
    }
    switch (_sort) {
      case GallerySort.newest:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case GallerySort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case GallerySort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case GallerySort.artist:
        list.sort((a, b) => a.artistName.compareTo(b.artistName));
      case GallerySort.priceHigh:
        list.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
      case GallerySort.priceLow:
        list.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    }
    return list;
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
    ref.read(gallerySelectModeProvider.notifier).state = true;
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    ref.read(gallerySelectModeProvider.notifier).state = false;
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

    HapticFeedback.mediumImpact();
    _exitSelectMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count painting${count > 1 ? 's' : ''} moved to trash',
          ),
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
  Widget build(BuildContext context) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings = paintingsAsync.valueOrNull ?? const <Painting>[];
    final loading =
        paintingsAsync.isLoading && paintingsAsync.valueOrNull == null;
    final filtered = _filter(paintings);
    final visible = filtered.take(_visibleCount).toList();
    final categories = <String>[
      ...AppConstants.categories.where(
        (c) => paintings.any((p) => p.category == c && !p.isDeleted),
      ),
    ];

    return PopScope(
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
        body: RefreshIndicator(
          backgroundColor: Theme.of(context).colorScheme.surface,
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 2.5,
          displacement: 60,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.invalidate(paintingsProvider);
          },
          child: Semantics(
            label: '${visible.length} paintings in gallery',
            liveRegion: true,
            child: CustomScrollView(
              controller: _controller,
              slivers: [
                SliverToBoxAdapter(
                  child: _GalleryHeader(
                    view: _view,
                    onViewChanged: (v) => setState(() => _view = v),
                    onSortChanged: (s) => setState(() => _sort = s),
                    onSearchTap: () => context.push('/search'),
                    favoritesOnly: _favoritesOnly,
                    onFavoritesToggle: () =>
                        setState(() => _favoritesOnly = !_favoritesOnly),
                  ),
                ),
                if (categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: AppSpacing.screenPadding,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: const Text('All'),
                              selected: _category == null,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _category = null);
                              },
                            ),
                          ),
                          for (final c in categories)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.xs,
                              ),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: _category == c,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _category = c);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (loading)
                  SliverPadding(
                    padding: AppSpacing.screenPadding,
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        (context, i) => const _GallerySkeletonCard(),
                        childCount: 12,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: AppBreakpoints.galleryColumns(context),
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.82,
                      ),
                    ),
                  )
                else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.photo_library_outlined,
                      title: 'No artworks here yet',
                      subtitle:
                          'Upload a painting to start building your gallery.',
                      actionLabel: 'Add painting',
                      onAction: () => context.push('/painting/new'),
                    ),
                  )
                else
                  switch (_view) {
                    GalleryView.grid => SliverPadding(
                      padding: AppSpacing.screenPadding,
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          (context, i) => PaintingGridCard(
                            painting: visible[i],
                            heroTag: 'painting-${visible[i].id}',
                            staggerIndex: i,
                            selectMode: _selectMode,
                            selected: _selectedIds.contains(visible[i].id),
                            onSelect: () => _toggleSelect(visible[i].id),
                            onLongPress: () => _enterSelectMode(visible[i].id),
                          ),
                          childCount: visible.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppBreakpoints.galleryColumns(
                            context,
                          ),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.82,
                        ),
                      ),
                    ),
                    GalleryView.list => SliverPadding(
                      padding: AppSpacing.screenPadding,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: PaintingListTile(
                              painting: visible[i],
                              selectMode: _selectMode,
                              selected: _selectedIds.contains(visible[i].id),
                              onSelect: () => _toggleSelect(visible[i].id),
                              onLongPress: () =>
                                  _enterSelectMode(visible[i].id),
                            ),
                          ),
                          childCount: visible.length,
                        ),
                      ),
                    ),
                    GalleryView.masonry => SliverPadding(
                      padding: AppSpacing.screenPadding,
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount:
                            AppBreakpoints.galleryColumns(context) ~/ 2 + 1,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childCount: visible.length,
                        itemBuilder: (context, i) =>
                            _MasonryCard(painting: visible[i], staggerIndex: i),
                      ),
                    ),
                    GalleryView.table => SliverToBoxAdapter(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: const GalleryTableView(),
                        ),
                      ),
                    ),
                    GalleryView.split => SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 100,
                        child: const SplitPanelView(),
                      ),
                    ),
                  },
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  final GalleryView view;
  final ValueChanged<GalleryView> onViewChanged;
  final ValueChanged<GallerySort> onSortChanged;
  final VoidCallback onSearchTap;
  final bool favoritesOnly;
  final VoidCallback onFavoritesToggle;

  const _GalleryHeader({
    required this.view,
    required this.onViewChanged,
    required this.onSortChanged,
    required this.onSearchTap,
    required this.favoritesOnly,
    required this.onFavoritesToggle,
  });

  static const _viewIcons = {
    GalleryView.grid: Icons.grid_view,
    GalleryView.list: Icons.view_agenda_outlined,
    GalleryView.masonry: Icons.dashboard_customize_outlined,
    GalleryView.table: Icons.table_chart_rounded,
    GalleryView.split: Icons.view_column_rounded,
  };
  static const _viewLabels = {
    GalleryView.grid: 'Grid',
    GalleryView.list: 'List',
    GalleryView.masonry: 'Gallery',
    GalleryView.table: 'Table',
    GalleryView.split: 'Split',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Web shell's top bar already names this page; keep just breathing room.
    final topPad = kIsWeb
        ? AppSpacing.xs
        : AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4;
    final hPad = context.adaptiveSpace(AppSpacing.md);

    return Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean title row: just title (mobile) + 2 action icons.
              Row(
                children: [
                  if (kIsWeb)
                    const Spacer()
                  else
                    Expanded(
                      child: Text(
                        'Gallery',
                        style: AppTheme.display(
                          context,
                          size: context.adaptiveFont(28),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Favorites',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onFavoritesToggle();
                    },
                    icon: Icon(
                      favoritesOnly ? Icons.favorite : Icons.favorite_border,
                      color: favoritesOnly ? const Color(0xFFFF6B6B) : null,
                    ),
                  ),
                  PopupMenuButton<GallerySort>(
                    tooltip: 'Sort',
                    onSelected: onSortChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: GallerySort.newest,
                        child: Text('Newest first'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.oldest,
                        child: Text('Oldest first'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.title,
                        child: Text('Title (A–Z)'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.artist,
                        child: Text('Artist name'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.priceHigh,
                        child: Text('Price: high → low'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.priceLow,
                        child: Text('Price: low → high'),
                      ),
                    ],
                    icon: const Icon(Icons.sort),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // View switcher pill row
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    for (final v in GalleryView.values) ...[
                      if (v != GalleryView.values.first)
                        const SizedBox(width: 6),
                      _ViewPill(
                        icon: _viewIcons[v]!,
                        label: _viewLabels[v]!,
                        selected: v == view,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onViewChanged(v);
                        },
                      ),
                    ],
                    const Spacer(),
                    Material(
                      color: scheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                        onTap: onSearchTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search,
                                size: 16,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Search',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(
          key: ValueKey('gallery-header'),
          onPlay: (c) =>
              MediaQuery.disableAnimationsOf(context) ? c.stop() : null,
        )
        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}

/// Animated pill-style view switcher button.
class _ViewPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary
            : scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? scheme.onPrimary : scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder card shown while the gallery is first loading.
class _GallerySkeletonCard extends StatelessWidget {
  const _GallerySkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      child: const SkeletonBox(height: 300),
    );
  }
}

/// Masonry cell with variable height driven by the artwork's orientation.
class _MasonryCard extends StatelessWidget {
  final Painting painting;
  final int? staggerIndex;

  const _MasonryCard({required this.painting, this.staggerIndex});

  @override
  Widget build(BuildContext context) {
    final isPortrait = painting.orientation == 'Portrait';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: isPortrait ? 3 / 4 : 4 / 3,
          child: PaintingGridCard(
            painting: painting,
            staggerIndex: staggerIndex,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
          child: Text(
            painting.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
