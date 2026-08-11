import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_spacing.dart';
import 'motion.dart';

/// Frosted glass surface with refined shadows and gradient — the primary
/// container for floating cards, bottom bars, and feature highlights.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? tint;
  final double elevation;
  final bool hasShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.radius = AppSpacing.radiusCard,
    this.onTap,
    this.gradient,
    this.tint,
    this.elevation = 0,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final outline = theme.colorScheme.outlineVariant;
    final onSurface = theme.colorScheme.onSurface;

    final baseColor = tint ?? surface;
    final effectiveGradient =
        gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            isDark
                ? baseColor.withValues(alpha: 0.95)
                : baseColor.withValues(alpha: 0.98),
          ],
        );

    final card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline.withValues(alpha: 0.5), width: 0.5),
        boxShadow: hasShadow
            ? (isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ])
            : null,
      ),
      child: child,
    );

    final Widget result;
    if (onTap == null) {
      result = card;
    } else {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor: onSurface.withValues(alpha: 0.05),
          highlightColor: onSurface.withValues(alpha: 0.03),
          child: card,
        ),
      );
    }

    // Premium entrance: cards drift up softly as they fade in, and press
    // down slightly when tapped.
    return PressScale(
      child: result
          .animate()
          .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.03, duration: 420.ms, curve: Curves.easeOutCubic),
    );
  }
}

/// Elevated card with subtle shadow — used for content sections.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child:
          Card(
                margin: margin ?? EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  child: Padding(padding: padding, child: child),
                ),
              )
              .animate()
              .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
              .slideY(
                begin: 0.03,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}

/// Section heading used across dashboards with refined typography.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
          padding: padding ?? const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// A shimmer loading placeholder.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
