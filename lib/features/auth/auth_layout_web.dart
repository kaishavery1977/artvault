import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';

/// Web-specific horizontal split-screen auth layout.
/// Left side: immersive brand visual with animated particles and gradient.
/// Right side: glassmorphism form card with all auth controls.
class AuthLayoutWeb extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const AuthLayoutWeb({
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
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Left side: immersive brand visual (40%)
          Expanded(
            flex: 4,
            child: _BrandVisual(isDark: isDark, scheme: scheme),
          ),
          // Right side: form card (60%)
          Expanded(
            flex: 6,
            child: Container(
              color: isDark ? const Color(0xFF0A0B14) : Colors.white,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette, size: 42, color: scheme.primary)
                              .animate()
                              .scale(
                                begin: const Offset(0.7, 0.7),
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: AppSpacing.md),
                          Center(
                            child: GradientShimmerText(
                              text: 'ArtVault',
                              style: AppTheme.display(context, size: 32),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _GlassFormCard(
                            title: title,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...children,
                                if (footer != null) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  footer!,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Immersive brand visual for the left side of the login screen.
class _BrandVisual extends StatefulWidget {
  final bool isDark;
  final ColorScheme scheme;
  const _BrandVisual({required this.isDark, required this.scheme});

  @override
  State<_BrandVisual> createState() => _BrandVisualState();
}

class _BrandVisualState extends State<_BrandVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0B14), Color(0xFF111222), Color(0xFF0D0E1A)],
            ),
          ),
        ),
        // Animated floating orbs
        AnimatedBuilder(
          animation: _orbCtrl,
          builder: (_, _) {
            final t = _orbCtrl.value;
            return Stack(
              children: [
                Positioned(
                  left: 40 + 30 * t,
                  top: 60 + 40 * t,
                  child: _GlowOrbWeb(
                    size: 280,
                    color: AppColors.violet500.withValues(alpha: 0.25),
                  ),
                ),
                Positioned(
                  right: 30 + 20 * (1 - t),
                  bottom: 80 + 30 * t,
                  child: _GlowOrbWeb(
                    size: 220,
                    color: AppColors.cyan400.withValues(alpha: 0.18),
                  ),
                ),
                Positioned(
                  left: 120 - 20 * t,
                  bottom: 160 + 20 * (1 - t),
                  child: _GlowOrbWeb(
                    size: 180,
                    color: AppColors.rose400.withValues(alpha: 0.12),
                  ),
                ),
              ],
            );
          },
        ),
        // Center content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.secondary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .scaleXY(
                    begin: 0.6,
                    duration: 1200.ms,
                    curve: Curves.easeOutBack,
                  )
                  .then()
                  .shimmer(
                    duration: 2000.ms,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
              const SizedBox(height: 32),
              Text(
                'Your Private Gallery',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.3),
              const SizedBox(height: 12),
              Text(
                'Track · Catalogue · Discover',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent.withValues(alpha: 0.6),
                ),
              ).animate(delay: 1000.ms).fadeIn(duration: 800.ms),
            ],
          ),
        ),
        // Bottom attribution
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Text(
              'Crafted by Kais Havery',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ).animate(delay: 1500.ms).fadeIn(duration: 600.ms),
          ),
        ),
      ],
    );
  }
}

class _GlowOrbWeb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrbWeb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Glassmorphism form card for the right side.
class _GlassFormCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassFormCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.violet400.withValues(alpha: 0.12)
              : AppColors.violet200.withValues(alpha: 0.3),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.04);
  }
}
