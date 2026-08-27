import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Premium button with 3D depth, glow effect, and press animation.
class PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool loading;
  final bool expanded;

  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.loading = false,
    this.expanded = true,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowIntensity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowIntensity = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btnColor = widget.color ?? scheme.primary;
    final fg = widget.textColor ?? Colors.white;
    final enabled = widget.onPressed != null && !widget.loading;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.expanded ? double.infinity : null,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            gradient: LinearGradient(
              colors: [btnColor, btnColor.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              // 3D shadow
              BoxShadow(
                color: btnColor.withValues(alpha: 0.3 * _glowIntensity.value),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              // Glow
              BoxShadow(
                color: btnColor.withValues(alpha: 0.15 * _glowIntensity.value),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              splashColor: fg.withValues(alpha: 0.15),
              highlightColor: fg.withValues(alpha: 0.05),
              onTapDown: enabled ? (_) => _controller.forward() : null,
              onTapUp: enabled ? (_) => _controller.reverse() : null,
              onTapCancel: enabled ? () => _controller.reverse() : null,
              onTap: enabled ? widget.onPressed : null,
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: fg, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating action button with 3D glow pulse.
class PremiumFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  const PremiumFAB({super.key, required this.icon, this.onPressed, this.color});

  @override
  State<PremiumFAB> createState() => _PremiumFABState();
}

class _PremiumFABState extends State<PremiumFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = reduced ? 0.5 : 0.3 + 0.2 * _pulseController.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4 * pulse),
                blurRadius: 20 + 8 * pulse,
                spreadRadius: 2 * pulse,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: widget.onPressed,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            highlightElevation: 0,
            child: Icon(widget.icon, size: 26),
          ),
        );
      },
    );
  }
}
