import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a widget with Semantics for screen readers.
/// Use for icon-only buttons, status messages, and interactive elements
/// that don't have visible text labels.
class SemanticLabel extends StatelessWidget {
  final String label;
  final Widget child;
  final bool? readOnly;
  final VoidCallback? onTap;

  const SemanticLabel({
    super.key,
    required this.label,
    required this.child,
    this.readOnly,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: onTap != null,
      readOnly: readOnly ?? false,
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: child)
          : child,
    );
  }
}

/// Hides decorative elements from screen readers.
/// Use for spacers, dividers, background glows, and ornamental images.
class SemanticHidden extends StatelessWidget {
  final Widget child;

  const SemanticHidden({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: child);
  }
}

/// Announces a status change to screen readers (e.g. "3 items restored").
class SemanticAnnounce extends StatelessWidget {
  final String message;
  final Widget child;

  const SemanticAnnounce({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, label: message, child: child);
  }
}

/// Wraps a form with FocusTraversalGroup for logical tab order.
class AccessibleForm extends StatelessWidget {
  final List<Widget> children;
  final Axis traversalAxis;

  const AccessibleForm({
    super.key,
    required this.children,
    this.traversalAxis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Makes an image decorative (hidden from screen readers) when it's
/// purely illustrative (aurora background, shimmer, etc.).
class DecorativeImage extends StatelessWidget {
  final Widget child;

  const DecorativeImage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '',
      child: ExcludeSemantics(child: child),
    );
  }
}

/// "Skip to main content" link for keyboard users.
/// Place at the top of the widget tree. Tapping or pressing Enter/Space
/// moves focus to the provided [focusNode] (the main content area).
/// Visually hidden until focused via keyboard (Tab key).
class SkipNavigation extends StatefulWidget {
  final FocusNode contentFocusNode;
  final String label;

  const SkipNavigation({
    super.key,
    required this.contentFocusNode,
    this.label = 'Skip to main content',
  });

  @override
  State<SkipNavigation> createState() => _SkipNavigationState();
}

class _SkipNavigationState extends State<SkipNavigation> {
  bool _focused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: AnimatedOpacity(
        opacity: _focused ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedSlide(
          offset: _focused ? Offset.zero : const Offset(0, -0.5),
          duration: const Duration(milliseconds: 150),
          child: Focus(
            focusNode: _focusNode,
            child: GestureDetector(
              onTap: _skipToContent,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _skipToContent() {
    widget.contentFocusNode.requestFocus();
  }
}

/// Wraps a dialog or modal with focus management.
/// Traps keyboard focus within the dialog (Tab cycles through focusable
/// widgets inside), and pressing Escape closes it.
class FocusTrappedDialog extends StatefulWidget {
  final Widget child;
  final VoidCallback? onEscape;

  const FocusTrappedDialog({super.key, required this.child, this.onEscape});

  @override
  State<FocusTrappedDialog> createState() => _FocusTrappedDialogState();
}

class _FocusTrappedDialogState extends State<FocusTrappedDialog> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onEscape?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusTraversalGroup(child: widget.child),
    );
  }
}

/// Keyboard-accessible button that can be activated with Enter or Space.
/// Use for custom widgets that act like buttons but aren't native Button-style.
class KeyboardActivatable extends StatelessWidget {
  final VoidCallback onActivate;
  final Widget child;
  final String? semanticsLabel;

  const KeyboardActivatable({
    super.key,
    required this.onActivate,
    required this.child,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              onActivate();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(onTap: onActivate, child: child),
      ),
    );
  }
}
