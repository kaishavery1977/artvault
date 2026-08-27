import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Floating ambient orbs that drift slowly in the background, creating a
/// premium, atmospheric feel. Each orb is a soft radial gradient circle
/// with independent drift speed and phase.
///
/// Usage:
///   Stack(children: [
///     FloatingOrbs(count: 5),
///     MyContent(),
///   ])
class FloatingOrbs extends StatefulWidget {
  final int count;
  final List<Color>? colors;
  final double minSize;
  final double maxSize;
  final bool animated;

  const FloatingOrbs({
    super.key,
    this.count = 5,
    this.colors,
    this.minSize = 80,
    this.maxSize = 200,
    this.animated = true,
  });

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_OrbData> _orbs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final rng = math.Random(42); // deterministic for consistent layout
    _orbs = List.generate(widget.count, (i) {
      final defaultColors = [
        const Color(0x228AB4F8), // blue
        const Color(0x22F59E0B), // gold
        const Color(0x2214B8A6), // teal
        const Color(0x22F472B6), // pink
        const Color(0x22A78BFA), // purple
      ];
      final palette = widget.colors ?? defaultColors;
      return _OrbData(
        color: palette[i % palette.length],
        size: widget.minSize + rng.nextDouble() * (widget.maxSize - widget.minSize),
        speedX: 0.3 + rng.nextDouble() * 0.7,
        speedY: 0.2 + rng.nextDouble() * 0.5,
        phaseX: rng.nextDouble() * math.pi * 2,
        phaseY: rng.nextDouble() * math.pi * 2,
        offsetX: rng.nextDouble(),
        offsetY: rng.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final reduceMotion = mq?.disableAnimations ?? false;
    final isLowEnd = (mq?.devicePixelRatio ?? 3.0) < 2.5 || reduceMotion;
    if (!widget.animated || isLowEnd) {
      return Stack(children: _buildOrbs(0));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(children: _buildOrbs(_controller.value)),
    );
  }

  List<Widget> _buildOrbs(double t) {
    return _orbs.map((orb) {
      final x = math.sin(t * math.pi * 2 * orb.speedX + orb.phaseX);
      final y = math.cos(t * math.pi * 2 * orb.speedY + orb.phaseY);
      return Positioned(
        left: orb.offsetX * 100 + x * 40,
        top: orb.offsetY * 100 + y * 30,
        child: Container(
          width: orb.size,
          height: orb.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                orb.color,
                orb.color.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _OrbData {
  final Color color;
  final double size;
  final double speedX;
  final double speedY;
  final double phaseX;
  final double phaseY;
  final double offsetX;
  final double offsetY;

  const _OrbData({
    required this.color,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phaseX,
    required this.phaseY,
    required this.offsetX,
    required this.offsetY,
  });
}
