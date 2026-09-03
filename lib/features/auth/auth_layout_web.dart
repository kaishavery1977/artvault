import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Web split-screen auth experience.
///
/// Left: an interactive "stage" — display typography over aurora light,
/// a pointer-tilted brand canvas and depth-layered floating chips. The
/// whole stage parallaxes gently with the pointer.
/// Right: a true-glass form card (BackdropFilter blur) over a soft
/// theme-aware wash.
///
/// Below 860px the stage collapses to a compact brand header and the card
/// centers over the aurora. Reduced motion renders everything statically.
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
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          return _ParallaxHost(
            reduce: reduce,
            child: compact
                ? _CompactLayout(
                    title: title,
                    subtitle: subtitle,
                    footer: footer,
                    children: children,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Interactive hero stage (≈45%).
                      Expanded(flex: 45, child: _HeroStage(reduce: reduce)),
                      // Form column over aurora wash (≈55%).
                      Expanded(
                        flex: 55,
                        child: _FormPanel(
                          title: title,
                          subtitle: subtitle,
                          footer: footer,
                          children: children,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Watches the pointer over the whole screen and hands normalized -1..1
/// offsets down so stage layers can parallax at different depths.
class _ParallaxHost extends StatefulWidget {
  final Widget child;
  final bool reduce;

  const _ParallaxHost({required this.child, required this.reduce});

  @override
  State<_ParallaxHost> createState() => _ParallaxHostState();
}

class _ParallaxHostState extends State<_ParallaxHost> {
  final ValueNotifier<Offset> _pointer = ValueNotifier(Offset.zero);

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.reduce
        ? widget.child
        : ListenableBuilder(
            listenable: _pointer,
            builder: (context, _) => widget.child,
          );

    return MouseRegion(
      onHover: widget.reduce
          ? null
          : (event) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              final local = box.globalToLocal(event.position);
              _pointer.value = Offset(
                ((local.dx / box.size.width) - 0.5) * 2,
                ((local.dy / box.size.height) - 0.5) * 2,
              );
            },
      onExit: widget.reduce ? null : (_) => _pointer.value = Offset.zero,
      child: _ParallaxInherited(
        notifier: _pointer,
        reduce: widget.reduce,
        child: stage,
      ),
    );
  }
}

/// Makes [_pointer] available to hero layers without rebuilding everything.
class _ParallaxInherited extends InheritedNotifier<ValueNotifier<Offset>> {
  final bool reduce;

  const _ParallaxInherited({
    required super.notifier,
    required this.reduce,
    required super.child,
  });

  static _ParallaxInherited? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ParallaxInherited>();

  Offset get offset => reduce ? Offset.zero : (notifier?.value ?? Offset.zero);
}

/// Depth-parallax wrapper: shifts its child by `factor * pointer`.
class _ParallaxLayer extends StatelessWidget {
  final Widget child;
  final double factor;

  const _ParallaxLayer({required this.child, required this.factor});

  @override
  Widget build(BuildContext context) {
    final host = _ParallaxInherited.maybeOf(context);
    if (host == null || host.reduce) return child;
    final o = host.offset;
    return Transform.translate(
      offset: Offset(o.dx * factor * 14, o.dy * factor * 10),
      child: child,
    );
  }
}

// ===========================================================================
// Compact layout (< 860px): small brand header, then the glass card centered
// over the aurora wash.
// ===========================================================================
class _CompactLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const _CompactLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _AuroraWash(),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _BrandMark(size: 40),
                        const SizedBox(width: 10),
                        Text(
                          'ArtVault',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _GlassFormCard(
                      title: title,
                      subtitle: subtitle,
                      footer: footer,
                      children: children,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Wide layout — interactive stage + form panel.
// ===========================================================================
class _HeroStage extends StatelessWidget {
  final bool reduce;
  const _HeroStage({required this.reduce});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep layered background.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF070810),
                      Color(0xFF0E0F1C),
                      Color(0xFF0A0B16),
                    ]
                  : const [
                      Color(0xFFF4F2FD),
                      Color(0xFFF0EFFB),
                      Color(0xFFF6F4FD),
                    ],
            ),
          ),
        ),
        // Parallax aurora orbs (three depth layers).
        _ParallaxLayer(
          factor: 0.9,
          child: _Orb(
            size: 340,
            top: 40,
            left: 30,
            color: AppColors.violet500.withValues(alpha: 0.26),
          ),
        ),
        _ParallaxLayer(
          factor: -0.7,
          child: _Orb(
            size: 280,
            bottom: 60,
            right: 20,
            color: AppColors.cyan400.withValues(alpha: 0.18),
          ),
        ),
        _ParallaxLayer(
          factor: 0.45,
          child: _Orb(
            size: 200,
            bottom: 200,
            left: 160,
            color: AppColors.rose400.withValues(alpha: 0.14),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow brand line.
                Row(
                  children: [
                    const _BrandMark(size: 38),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ArtVault',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'PRIVATE GALLERY',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Display statement.
                _stageText(
                  context,
                  reduce,
                  Text(
                    'Your art,\ngallery-grade.',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 44,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: scheme.onSurface,
                    ),
                  ),
                  delayMs: 100,
                ),
                const SizedBox(height: 18),
                Container(
                  width: 56,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _stageText(
                  context,
                  reduce,
                  Text(
                    'Catalogue, value and protect your collection\nin one private vault — on any device, offline-first.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  delayMs: 250,
                ),
                const SizedBox(height: 34),
                // Floating glass chips at different parallax depths.
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ParallaxLayer(
                      factor: 1.0,
                      child: _FeatureChip(
                        icon: Icons.auto_awesome_rounded,
                        label: 'AI valuation',
                        reduce: reduce,
                        delayMs: 450,
                      ),
                    ),
                    _ParallaxLayer(
                      factor: -0.8,
                      child: _FeatureChip(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Condition reports',
                        reduce: reduce,
                        delayMs: 600,
                      ),
                    ),
                    _ParallaxLayer(
                      factor: 0.6,
                      child: _FeatureChip(
                        icon: Icons.layers_outlined,
                        label: '3D view',
                        reduce: reduce,
                        delayMs: 750,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Attribution.
                Text(
                  'Crafted by Kais Havery',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.32),
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

class _FormPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _AuroraWash(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome to your vault',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _GlassFormCard(
                      title: title,
                      subtitle: null,
                      footer: footer,
                      children: children,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Entrance helper: renders static under reduced motion, otherwise fades
/// the child in with a gentle rise after [delayMs].
Widget _stageText(
  BuildContext context,
  bool reduce,
  Widget text, {
  required int delayMs,
}) {
  if (reduce) return text;
  return text
      .animate(delay: delayMs.ms)
      .fadeIn(duration: 900.ms)
      .slideY(begin: 0.05, duration: 900.ms, curve: Curves.easeOutCubic);
}

/// Shared soft aurora wash (form side / compact backdrop). Static gradients.
class _AuroraWash extends StatelessWidget {
  const _AuroraWash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surface),
          _Orb(
            size: 420,
            right: -120,
            top: -120,
            color: AppColors.violet500.withValues(alpha: isDark ? 0.16 : 0.10),
          ),
          _Orb(
            size: 360,
            left: -140,
            bottom: -120,
            color: AppColors.cyan400.withValues(alpha: isDark ? 0.13 : 0.09),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared atoms
// ===========================================================================

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet500, AppColors.cyan400],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet500.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: Icon(Icons.palette_rounded, size: size * 0.5, color: Colors.white),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double? top, left, right, bottom;
  final Color color;

  const _Orb({
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Small frosted pill used on the hero stage.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool reduce;
  final int delayMs;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.reduce,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );

    if (reduce) return chip;
    return chip
        .animate(delay: delayMs.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

/// True-glass form card: BackdropFilter blur + hairline gradient ring.
class _GlassFormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  const _GlassFormCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final card = Container(
      // 1px base lets the gradient read as a hairline ring around the glass.
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        // Hairline gradient ring.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
            Colors.transparent,
            scheme.secondary.withValues(alpha: isDark ? 0.2 : 0.12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 60,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: isDark
                  ? const Color(0xFF12141F).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.82),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (reduce) return card;
    return card
        .animate()
        .fadeIn(duration: 650.ms, delay: 150.ms)
        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }
}
