import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Ambient gradient painted behind every route so translucent surfaces read
/// as glass. The base color matches the theme's solid background, so text
/// contrast is preserved and the change is subtle in content areas.
///
/// Performance: the painter is fully static — it paints once and is cached in
/// a [RepaintBoundary], so it costs nothing per frame and is safe on low-end
/// devices. No animation, by design: the app must never lag on budget phones.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _AmbientPainter(isDark: isDark)),
          child,
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final bool isDark;

  _AmbientPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    // Soft color blobs in the brand palette (navy, gold, teal). Alphas are
    // deliberately low so surfaces and text keep their contrast.
    final radius = size.shortestSide * 0.55;
    final blobs = isDark
        ? [
            (
              AppColors.brand700.withValues(alpha: 0.42),
              Offset(size.width * 0.88, size.height * 0.10),
            ),
            (
              AppColors.gold500.withValues(alpha: 0.14),
              Offset(size.width * 0.06, size.height * 0.42),
            ),
            (
              AppColors.teal600.withValues(alpha: 0.16),
              Offset(size.width * 0.62, size.height * 0.88),
            ),
          ]
        : [
            (
              AppColors.brand300.withValues(alpha: 0.28),
              Offset(size.width * 0.88, size.height * 0.10),
            ),
            (
              AppColors.gold200.withValues(alpha: 0.40),
              Offset(size.width * 0.04, size.height * 0.45),
            ),
            (
              AppColors.teal200.withValues(alpha: 0.40),
              Offset(size.width * 0.66, size.height * 0.90),
            ),
          ];

    for (final (color, center) in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
