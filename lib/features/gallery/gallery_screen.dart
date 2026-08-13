import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import 'painting_card.dart';

enum GalleryView { grid, list, masonry }

enum GallerySort { newest, oldest, title, priceHigh, priceLow }

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  GalleryView _view = GalleryView.grid;
  GallerySort _sort = GallerySort.newest;
  String? _category;
  bool _favoritesOnly = false;
  final ScrollController _controller = ScrollController();
  int _visibleCount = 18;

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
      case GallerySort.priceHigh:
        list.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
      case GallerySort.priceLow:
        list.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    }
    return list;
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

    return Scaffold(
      body: CustomScrollView(
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
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No artworks here yet',
                subtitle: 'Upload a painting to start building your gallery.',
              ),
            )
          else
            switch (_view) {
              GalleryView.grid => SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => PaintingGridCard(
                      painting: visible[i],
                      heroTag: 'painting-${visible[i].id}',
                      staggerIndex: i,
                    ),
                    childCount: visible.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppBreakpoints.galleryColumns(context),
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
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PaintingListTile(painting: visible[i]),
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
            },
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gallery',
                  style: AppTheme.display(context, size: 28),
                ),
              ),
              IconButton(
                tooltip: 'Favorites',
                onPressed: onFavoritesToggle,
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
                    value: GallerySort.priceHigh,
                    child: Text('Price: high to low'),
                  ),
                  PopupMenuItem(
                    value: GallerySort.priceLow,
                    child: Text('Price: low to high'),
                  ),
                ],
                icon: const Icon(Icons.sort),
              ),
              SegmentedButton<GalleryView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: GalleryView.grid,
                    icon: Icon(Icons.grid_view, size: 18),
                  ),
                  ButtonSegment(
                    value: GalleryView.list,
                    icon: Icon(Icons.view_agenda_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: GalleryView.masonry,
                    icon: Icon(Icons.dashboard_customize_outlined, size: 18),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (s) => onViewChanged(s.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: scheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: onSearchTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Search paintings, artists, colors…',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )
        // Header settles in as one unit, then the search bar follows — the
        // toolbar choreography every list screen in the app shares.
        .animate(key: ValueKey('gallery-header'))
        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 420.ms, curve: Curves.easeOutCubic);
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
