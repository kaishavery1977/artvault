import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium animated gradient background with subtle color shifts and
/// optional floating light rays. Used behind splash, login, and home.
class PremiumBackground extends StatefulWidget {
  final List<Color>? colors;
  final bool showRays;
  final Widget? child;

  const PremiumBackground({
    super.key,
    this.colors,
    this.showRays = true,
    this.child,
  });

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.maybeOf(context);
    final reduceMotion = mq?.disableAnimations ?? false;
    final isLowEnd = (mq?.devicePixelRatio ?? 3.0) < 2.5 || reduceMotion;

    final defaultColors = isDark
        ? [
            const Color(0xFF0A0A14),
            const Color(0xFF12122A),
            const Color(0xFF1A1030),
            const Color(0xFF0E1628),
          ]
        : [
            const Color(0xFFF8F9FC),
            const Color(0xFFEEF0F8),
            const Color(0xFFE8ECF4),
            const Color(0xFFF0F2F8),
          ];

    final colors = widget.colors ?? defaultColors;

    return Stack(
      children: [
        // Base gradient
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Shift gradient angle slowly
            final angle = t * math.pi * 2;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(
                    math.cos(angle) * 0.5,
                    math.sin(angle) * 0.5 - 0.5,
                  ),
                  end: Alignment(
                    -math.cos(angle) * 0.5,
                    -math.sin(angle) * 0.5 + 0.5,
                  ),
                  colors: colors,
                ),
              ),
            );
          },
        ),

        // Floating light rays — hidden on low-end / reduced motion
        if (widget.showRays && !isDark && !isLowEnd)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _LightRaysPainter(
                  progress: _controller.value,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
          ),

        // Subtle noise texture overlay (simulated with random dots)
        if (!isDark)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),

        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Painter that draws subtle animated light rays.
class _LightRaysPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LightRaysPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.7, size.height * 0.1);
    final rng = math.Random(42);

    for (var i = 0; i < 8; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi / 4);
      final length = size.height * (0.3 + rng.nextDouble() * 0.4);
      final offset = Offset(
        center.dx + math.cos(angle) * 20,
        center.dy + math.sin(angle) * 20,
      );
      final end = Offset(
        offset.dx + math.cos(angle + 0.3) * length,
        offset.dy + math.sin(angle + 0.3) * length,
      );
      canvas.drawLine(offset, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter old) =>
      old.progress != progress;
}
