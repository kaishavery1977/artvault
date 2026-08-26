import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/a11y.dart';
import '../../core/widgets/motion.dart';

/// Shared visual scaffold for auth screens — brand mark on top, frosted card
/// in the middle, gradient glow behind.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Ambient drifting aurora glow.
          const Positioned.fill(
            child: SemanticHidden(child: IgnorePointer(child: AuroraBackground())),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Icon(
                        Icons.palette,
                        size: 48,
                        color: scheme.primary,
                      ).animate(
                        onPlay: (c) => MediaQuery.disableAnimationsOf(context) ? c.stop() : null,
                      ).scale(
                        begin: const Offset(0.7, 0.7),
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: GradientShimmerText(
                          text: 'ArtVault',
                          style: AppTheme.display(context, size: context.adaptiveFont(32)),
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                            scheme.tertiary,
                          ],
                          duration: const Duration(milliseconds: 1100),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: AppSpacing.cardPadding,
                        decoration: BoxDecoration(
                          // Frosted glass card over the aurora glow — matches
                          // the GlassCard treatment. Decoration only.
                          color: scheme.surface.withValues(
                            alpha: isDark ? 0.72 : 0.82,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusXl,
                          ),
                          // Uniform sides: Flutter refuses to paint a
                          // borderRadius on a Border whose sides have
                          // different colors (asserts at paint time). The
                          // single glass-edge color keeps the frosted look.
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.20 : 0.65,
                            ),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            ...children,
                          ],
                        ),
                      ).animate(
                        onPlay: (c) => MediaQuery.disableAnimationsOf(context) ? c.stop() : null,
                      ).fadeIn(duration: 500.ms).slideY(begin: 0.06),
                      if (footer != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider used between the form and social sign-in options.
class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, this.label = 'or continue with'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: Divider(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}
