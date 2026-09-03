import 'package:flutter/material.dart';

/// Reusable skeleton shimmer placeholder for loading states on web.
/// Animates a gradient sweep across a placeholder shape.
class SkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const SkeletonShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Container(
          width: widget.isCircle ? widget.width : widget.width,
          height: widget.isCircle ? widget.width : widget.height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Gallery grid skeleton — shows shimmer placeholders for painting cards.
class GallerySkeleton extends StatelessWidget {
  const GallerySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
            ? 3
            : constraints.maxWidth > 500
            ? 2
            : 1;
        final spacing = 16.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(columns * 3, (i) {
            final heights = [
              220.0,
              280.0,
              180.0,
              260.0,
              200.0,
              240.0,
              300.0,
              190.0,
              250.0,
            ];
            return SizedBox(
              width: itemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonShimmer(
                    width: itemWidth,
                    height: heights[i % heights.length],
                    borderRadius: 12,
                  ),
                  const SizedBox(height: 8),
                  SkeletonShimmer(width: itemWidth * 0.7, height: 14),
                  const SizedBox(height: 6),
                  SkeletonShimmer(width: itemWidth * 0.4, height: 10),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

/// Table skeleton — shows shimmer placeholders for data table rows.
class TableSkeleton extends StatelessWidget {
  final int rows;
  final int columns;
  const TableSkeleton({super.key, this.rows = 8, this.columns = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: List.generate(columns, (colIndex) {
              final widths = [40.0, 120.0, 150.0, 80.0, 60.0];
              final w = colIndex < widths.length ? widths[colIndex] : 100.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SkeletonShimmer(width: w, height: 14, borderRadius: 4),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

/// Card skeleton — shows shimmer placeholders for card-style layouts.
class CardSkeleton extends StatelessWidget {
  final double height;
  const CardSkeleton({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonShimmer(width: 36, height: 36, borderRadius: 8),
              const SizedBox(width: 12),
              SkeletonShimmer(width: 120, height: 16),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonShimmer(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          SkeletonShimmer(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          SkeletonShimmer(width: 180, height: 12),
        ],
      ),
    );
  }
}
