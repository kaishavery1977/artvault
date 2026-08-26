import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// A card with 3D depth: perspective shadow, subtle tilt on scroll/gesture,
/// and a light-gradient overlay that shifts with the tilt angle.
///
/// Usage:
///   Depth3DCard(
///     child: MyContent(),
///     depth: 8,         // shadow depth in logical pixels
///     tiltEnabled: true, // responds to horizontal drag
///   )
class Depth3DCard extends StatefulWidget {
  final Widget child;
  final double depth;
  final bool tiltEnabled;
  final double maxTilt; // degrees
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;

  const Depth3DCard({
    super.key,
    required this.child,
    this.depth = 8,
    this.tiltEnabled = true,
    this.maxTilt = 8,
    this.borderRadius,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  State<Depth3DCard> createState() => _Depth3DCardState();
}

class _Depth3DCardState extends State<Depth3DCard>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0;
  double _tiltY = 0;
  late final AnimationController _pressAnim;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressAnim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressAnim.dispose();
    super.dispose();
  }

  void _resetTilt() {
    if (_tiltX != 0 || _tiltY != 0) {
      setState(() {
        _tiltX = 0;
        _tiltY = 0;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.tiltEnabled) return;
    final size = context.size;
    if (size == null) return;
    final dx = (e.localPosition.dx / size.width - 0.5) * 2;
    final dy = (e.localPosition.dy / size.height - 0.5) * 2;
    setState(() {
      _tiltX = dx * widget.maxTilt;
      _tiltY = dy * widget.maxTilt;
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    _resetTilt();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _resetTilt();
  }

  Matrix4 _buildTransform(double s) {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective
      ..rotateX(_tiltY * math.pi / 180)
      ..rotateY(-_tiltX * math.pi / 180)
      // ignore: deprecated_member_use
      ..scale(s);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusCard);
    final shadowColor = scheme.shadow;
    final depth = widget.depth;

    return Listener(
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pressScale,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: _buildTransform(_pressScale.value),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: widget.color ?? scheme.surface,
                  boxShadow: [
                    // Base shadow
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.15),
                      blurRadius: depth * 2,
                      offset: Offset(0, depth),
                      spreadRadius: -depth * 0.3,
                    ),
                    // Ambient light (top-left highlight)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: depth,
                      offset: Offset(-depth * 0.3, -depth * 0.3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: CustomPaint(
                    painter: _LightOverlayPainter(
                      tiltX: _tiltX,
                      tiltY: _tiltY,
                    ),
                    child: widget.padding != null
                        ? Padding(padding: widget.padding!, child: widget.child)
                        : widget.child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Painter that draws a subtle light gradient shifting with tilt angle.
class _LightOverlayPainter extends CustomPainter {
  final double tiltX;
  final double tiltY;

  _LightOverlayPainter({required this.tiltX, required this.tiltY});

  @override
  void paint(Canvas canvas, Size size) {
    // Shift the light source based on tilt
    final lightX = size.width * (0.3 + tiltX / 40);
    final lightY = size.height * (0.1 + tiltY / 40);

    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment(
        (lightX / size.width * 2 - 1).clamp(-1.0, 1.0),
        (lightY / size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
      radius: 1.2,
      colors: [
        Colors.white.withValues(alpha: 0.06),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6],
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _LightOverlayPainter old) =>
      old.tiltX != tiltX || old.tiltY != tiltY;
}
