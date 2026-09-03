import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Lightweight toast notification system for web.
/// Shows non-intrusive notifications in the bottom-right corner.
class WebToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color? color,
  }) {
    _current?.remove();
    final scheme = Theme.of(context).colorScheme;
    final toastColor = color ?? scheme.primary;

    _current = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        icon: icon,
        color: toastColor,
        onDismiss: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    Overlay.of(context).insert(_current!);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _current?.remove();
      _current = null;
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child:
            GestureDetector(
                  onTap: widget.onDismiss,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1C1F30)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hovered
                            ? widget.color.withValues(alpha: 0.4)
                            : widget.color.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _hovered ? 0.2 : 0.1,
                          ),
                          blurRadius: _hovered ? 20 : 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 18, color: widget.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.close,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.15, curve: Curves.easeOutCubic),
      ),
    );
  }
}
