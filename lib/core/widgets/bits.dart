import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:artvault/utils/image_helper.dart';
import 'package:artvault/utils/io_shim.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import 'motion.dart';

/// Small rounded tag chip with refined styling.
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? scheme.primary;

    return Material(
          color: base.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 13, color: base),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: base,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.9, 0.9),
          duration: 340.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// Tinted rounded icon tile — the shared leading-icon unit for list rows,
/// cards and quick actions. One icon-chip family across screens: a soft
/// translucent wash in the accent color under a rounded-square crop.
class IconWell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  /// Multiplier on the wash alpha — pass >1 for hover emphasis. The wash
  /// animates so hover states ease rather than snap.
  final double emphasis;

  const IconWell({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
    this.radius = AppSpacing.radiusMd,
    this.emphasis = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? 0.18 : 0.10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: (base * emphasis).clamp(0.0, 0.55)),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Circular avatar from an image or initials with refined design.
class Avatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final String? imageUrl;
  final double radius;

  const Avatar({
    super.key,
    required this.name,
    this.imagePath,
    this.imageUrl,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = (imageUrl?.isNotEmpty ?? false) ? imageUrl : null;
    final path = (imagePath?.isNotEmpty ?? false) ? imagePath : null;

    Widget child;
    if (url != null) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initials(context),
      );
    } else if (path != null) {
      child = kIsWeb
          ? _initials(context)
          : nativeImage(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initials(context),
            );
    } else {
      child = _initials(context);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [scheme.primary, scheme.tertiary]
              : [scheme.primary, scheme.secondary],
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipOval(
        child: SizedBox(width: radius * 2, height: radius * 2, child: child),
      ),
    );
  }

  Widget _initials(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        Formatters.initials(name),
        style: TextStyle(
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Dashboard metric card with icon, value and label — refined design.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// When set, the value counts up from its previous number instead of
  /// being rendered statically. [countFormat] receives the live number.
  final double? countValue;
  final String Function(double value)? countFormat;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.countValue,
    this.countFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final valueStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );

    return PressScale(
      child:
          Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  onTap: onTap,
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // Translucent fill so the ambient gradient shows
                      // through — decoration only, layout untouched.
                      color: surface.withValues(alpha: isDark ? 0.55 : 0.78),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusCard,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                        width: 0.5,
                      ),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    // A fixed-height FittedBox(scaleDown) column: the whole
                    // card content (icon, value, label) scales down as one
                    // unit when the grid cell is tighter than the content, so
                    // a StatCard can never overflow its cell on any device /
                    // font scale. (No flex children, so FittedBox is safe.)
                    child: SizedBox(
                      height: 96,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.2 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: Icon(icon, size: 22, color: color),
                            ),
                            const SizedBox(height: 10),
                            if (countValue != null && countFormat != null)
                              AnimatedCountUp(
                                value: countValue!,
                                format: countFormat!,
                                style: valueStyle,
                              )
                            else
                              Text(value, style: valueStyle),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
              .slideY(
                begin: 0.04,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}

/// A banner / info bar with icon, message and optional action.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.primary;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: base.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: base),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: base,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: base,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}
