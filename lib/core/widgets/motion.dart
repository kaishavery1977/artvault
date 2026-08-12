import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_spacing.dart';

/// Press feedback: scales the child down slightly while a pointer is down.
///
/// Uses raw pointer events (not the gesture arena), so it never steals taps
/// from the [InkWell] underneath — it only adds tactile press feedback.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final Duration duration;

  const PressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 110),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Number that counts up from its previous value whenever [value] changes.
///
/// Runs once on first mount (0 → value) and morphs on every subsequent
/// change, so dashboard stats feel alive. The [format] callback decides how
/// the number is rendered (e.g. currency or integer formatting) — pass a
/// closure that reads the current currency to get symbol changes for free.
class AnimatedCountUp extends StatefulWidget {
  final double value;
  final String Function(double value) format;
  final Duration duration;
  final TextStyle? style;

  const AnimatedCountUp({
    super.key,
    required this.value,
    required this.format,
    this.duration = const Duration(milliseconds: 850),
    this.style,
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _display = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _display = 0;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Morph from the currently-shown number, not from the raw old value,
      // so rapid updates feel continuous.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.value;
    final from = _display == 0 ? 0.0 : _display;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        _display = from + (target - from) * t;
        return Text(widget.format(_display), style: widget.style);
      },
    );
  }
}

/// Soft drifting aurora glow — animated gradient blobs drifting slowly behind
/// heroes. GPU-cheap (pure radial gradients + transforms, no blur).
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = isDark ? 0.20 : 0.14;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        final dx = math.sin(v * 2 * math.pi);
        final dy = math.cos(v * 2 * math.pi);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: scheme.surface)),
              // Warm gold blob — drifts top-left ⇄ bottom-right.
              Positioned(
                left: 120 + dx * 60,
                top: 30 + dy * 40,
                child: _blob(
                  color: scheme.tertiary.withValues(alpha: alpha),
                  size: 280,
                ),
              ),
              // Teal accent blob — counter-drifts bottom-left.
              Positioned(
                right: 80 + dy * 50,
                bottom: 40 - dx * 60,
                child: _blob(
                  color: scheme.primary.withValues(alpha: alpha * 0.8),
                  size: 240,
                ),
              ),
              // Static brand glow for depth.
              Positioned(
                left: -60,
                bottom: -80,
                child: _blob(
                  color: scheme.secondary.withValues(alpha: alpha * 0.7),
                  size: 300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Museum-style vignette: soft darkening at the edges with a faint warm
/// gallery-light cast in the corners.
class FilmVignette extends StatelessWidget {
  final double strength;

  const FilmVignette({super.key, this.strength = 0.32});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _VignettePainter(strength: strength),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  final double strength;

  _VignettePainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Edge darkening.
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 0.75,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: strength * 0.7),
        Colors.black.withValues(alpha: strength),
      ],
      stops: const [0.42, 0.78, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);

    // Warm gallery-light cast in the corners.
    final warm = RadialGradient(
      center: Alignment.bottomRight,
      radius: 1.4,
      colors: [
        const Color(0xFFF59E0B).withValues(alpha: strength * 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = warm);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// Wraps a list of widgets in staggered slide-up + fade-in entrances.
///
/// Each child animates a little after the previous one, so a column of form
/// fields or settings tiles cascades into view. The list is index-stable, so
/// rebuilding (e.g. toggling a visibility switch) doesn't replay the
/// animation. All transforms/opacity — GPU-cheap, no blur, safe on budget
/// phones.
List<Widget> staggerReveal(
  List<Widget> children, {
  Duration initialDelay = Duration.zero,
  Duration interval = const Duration(milliseconds: 140),
  Duration duration = const Duration(milliseconds: 650),
  double beginOffset = 0.08,
}) {
  return [
    for (var i = 0; i < children.length; i++)
      children[i]
          .animate(delay: initialDelay + interval * i)
          .slideY(begin: beginOffset)
          .fadeIn(duration: duration, curve: Curves.easeOutCubic),
  ];
}

/// Standard skeleton placeholder block used inside shimmer loaders.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppSpacing.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
