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

/// Text painted with an animated brand gradient that sweeps across once on
/// entry (Aceternity-style gradient text). With [loop] the sweep repeats
/// gently; under reduced motion it renders as a static gradient.
class GradientShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final Duration duration;
  final bool loop;

  const GradientShimmerText({
    super.key,
    required this.text,
    required this.style,
    required this.colors,
    this.duration = const Duration(milliseconds: 1400),
    this.loop = false,
  });

  @override
  State<GradientShimmerText> createState() => _GradientShimmerTextState();
}

class _GradientShimmerTextState extends State<GradientShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Created eagerly so the reduced-motion path (which never touches the
    // controller during its life) still disposes it cleanly — a lazy `late`
    // initializer would create the ticker mid-dispose and crash.
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
      if (widget.loop) {
        _controller.addStatusListener((status) {
          if (status == AnimationStatus.completed) _controller.reverse();
          if (status == AnimationStatus.dismissed) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Two layers: the base is an opaque palette gradient across the full text
    // (always readable), and the sweep is a narrow white band that travels
    // across it, brightening rather than erasing. Under reduced motion only
    // the base renders — the text is never invisible in any state.
    final baseStyle = widget.style.copyWith(color: Colors.white);
    final base = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final colors = widget.colors.length == 1
            ? [widget.colors.first, widget.colors.first]
            : widget.colors;
        return LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: colors,
          stops: [
            for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
          ],
        ).createShader(bounds);
      },
      child: Text(widget.text, style: baseStyle),
    );

    if (MediaQuery.disableAnimationsOf(context)) return base;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          child!,
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1 + 2.4 * _controller.value, 0),
              end: Alignment(-0.4 + 2.4 * _controller.value, 0),
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ).createShader(bounds),
            child: Text(widget.text, style: baseStyle),
          ),
        ],
      ),
      child: base,
    );
  }
}

/// A single horizontal shake, replayed each time [tick] increments — used
/// for wrong-passcode and failed-action feedback (Aceternity-style error
/// shake). Under reduced motion it renders statically.
class ShakeOnError extends StatelessWidget {
  final Widget child;
  final int tick;

  const ShakeOnError({super.key, required this.child, required this.tick});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // A fresh mount with tick 0 (e.g. the lock screen opening) must not
    // autoplay a shake — the effect only plays once the tick actually
    // increments, i.e. after a real error.
    if (tick <= 0) return child;
    return KeyedSubtree(
      // Changing the key remounts the subtree, replaying the shake effect.
      key: ValueKey('shake-$tick'),
      child: child.animate().shake(
        duration: const Duration(milliseconds: 420),
        hz: 9,
        rotation: math.pi / 64,
      ),
    );
  }
}

/// Slow cinematic settle-zoom on an image (Ken Burns). One-shot: the artwork
/// starts slightly larger and eases down to rest, so the viewer feels like
/// the lens is finding its focus. Under reduced motion it renders statically.
/// Slow push-in on a hero image (Ken Burns). Ticker-only — no timers, so
/// tests that end mid-flight stay clean; reduced motion renders statically.
class KenBurns extends StatefulWidget {
  final Widget child;
  final double begin;
  final Duration duration;

  const KenBurns({
    super.key,
    required this.child,
    this.begin = 1.06,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<KenBurns>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        final s = widget.begin + (1 - widget.begin) * _scale.value;
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}

/// 3D tilt that follows the pointer over a card (OriginKit-style). Tilt only
/// engages for touch-less pointers, so phones keep the plain press-scale
/// behavior; reduced motion renders statically. Small rotations only — cheap
/// transforms, no blur or repaint-heavy work.
class TiltCard extends StatefulWidget {
  final Widget child;
  final double maxTilt;

  const TiltCard({super.key, required this.child, this.maxTilt = 6});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  double _rx = 0;
  double _ry = 0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _rx = 0),
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(event.position);
        final nx = ((local.dx / box.size.width) - 0.5) * 2; // -1..1
        final ny = ((local.dy / box.size.height) - 0.5) * 2; // -1..1
        setState(() {
          _ry = nx * widget.maxTilt;
          _rx = -ny * widget.maxTilt;
        });
      },
      onExit: (_) => setState(() {
        _rx = 0;
        _ry = 0;
      }),
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(_rx * math.pi / 180)
              ..rotateY(_ry * math.pi / 180),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Ticker-only entrance: slides up + fades in after a delay.
///
/// Unlike flutter_animate's `delay:` (which schedules a `Future.delayed`
/// timer), the delay is folded into the [AnimationController] curve, so no
/// timer exists at all — a test can end at any point without a pending-timer
/// failure, and reduced motion renders statically.
class RevealEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginOffset;
  final bool reducedMotion;

  const RevealEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.beginOffset = 0.06,
    this.reducedMotion = false,
  });

  @override
  State<RevealEntrance> createState() => _RevealEntranceState();
}

class _RevealEntranceState extends State<RevealEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    // Wait out the delay as the idle prefix of the curve, so nothing moves
    // until the item's turn, then ease in over the remaining span.
    final startFrac = widget.delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(startFrac, 1.0, curve: Curves.easeOutCubic),
    );
    if (!widget.reducedMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the animation (not just read its value) so every tick
    // rebuilds the opacity/translate. Reading `_progress.value` directly
    // here would render the child once at opacity 0 and never animate in
    // until some unrelated rebuild — an invisible-content bug.
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final v = widget.reducedMotion ? 1.0 : _progress.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.beginOffset * (1 - v)),
            child: widget.child,
          ),
        );
      },
    );
  }
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
  Duration interval = const Duration(milliseconds: 90),
  Duration duration = const Duration(milliseconds: 480),
  double beginOffset = 0.06,
  BuildContext? context,
}) {
  final static = context != null && MediaQuery.disableAnimationsOf(context);
  return [
    for (var i = 0; i < children.length; i++)
      RevealEntrance(
        delay: static ? Duration.zero : initialDelay + interval * i,
        duration: duration,
        beginOffset: static ? 0 : beginOffset,
        reducedMotion: static,
        child: children[i],
      ),
  ];
}

/// Entrance for a lazily-built list item: slides up + fades in a touch after
/// its predecessor, so a scrolling list cascades instead of popping. Index is
/// clamped so a long list doesn't stack seconds of delay — later items enter
/// at a steady cadence. Reduced-motion gated like [staggerReveal].
Widget revealListItem(
  Widget child,
  int index, {
  Key? key,
  BuildContext? context,
}) {
  final static = context != null && MediaQuery.disableAnimationsOf(context);
  return RevealEntrance(
    // Pass a domain key through so list mutations keep each item's entrance
    // state attached to its identity, not its position in the list.
    key: key,
    delay: static
        ? Duration.zero
        : Duration(milliseconds: 32 * (index.clamp(0, 8))),
    duration: const Duration(milliseconds: 380),
    beginOffset: static ? 0 : 0.05,
    reducedMotion: static,
    child: child,
  );
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
