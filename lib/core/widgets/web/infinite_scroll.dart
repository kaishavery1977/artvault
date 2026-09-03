import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Infinite scroll wrapper for web lists.
/// Shows skeleton loading at the bottom when more data is loading.
/// Detects when user scrolls near the bottom and triggers loadMore.
class InfiniteScrollList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Future<void> Function()? onLoadMore;
  final bool isLoading;
  final bool hasMore;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry? padding;

  const InfiniteScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onLoadMore,
    this.isLoading = false,
    this.hasMore = true,
    this.emptyWidget,
    this.padding,
  });

  @override
  State<InfiniteScrollList> createState() => _InfiniteScrollListState();
}

class _InfiniteScrollListState extends State<InfiniteScrollList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Trigger load when 200px from the bottom
    if (currentScroll >= maxScroll - 200 &&
        widget.hasMore &&
        !widget.isLoading) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 && !widget.isLoading) {
      return widget.emptyWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing here yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
    }

    final totalItems = widget.itemCount + (widget.isLoading ? 3 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Real items
        if (index < widget.itemCount) {
          return widget.itemBuilder(context, index);
        }
        // Skeleton loading items at the bottom
        return _SkeletonTile(index: index - widget.itemCount);
      },
    );
  }
}

/// Skeleton loading tile with shimmer animation.
class _SkeletonTile extends StatelessWidget {
  final int index;
  const _SkeletonTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 300.ms)
        .shimmer(duration: 1200.ms);
  }
}
