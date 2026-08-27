import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Primary / secondary / ghost action button with loading + scale animation.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final IconData? icon;
  final bool secondary;
  final bool ghost;
  final Color? color;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.icon,
    this.secondary = false,
    this.ghost = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: secondary || ghost ? scheme.primary : scheme.onPrimary,
            ),
          )
        else ...[
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: secondary || ghost ? scheme.primary : scheme.onPrimary,
              ),
            ),
          ),
        ],
      ],
    );

    final enabled = onPressed != null && !loading;
    Widget button;

    if (ghost) {
      button = TextButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      );
    } else if (secondary) {
      button = OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(foregroundColor: scheme.primary),
        child: content,
      );
    } else {
      button = ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? scheme.primary,
        ),
        child: content,
      );
    }

    return button
        .animate(target: enabled ? 1 : 0)
        .scaleXY(begin: 0.985, end: 1, curve: Curves.easeOut, duration: 180.ms);
  }
}
