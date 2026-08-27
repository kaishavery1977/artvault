import 'package:flutter/material.dart';

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
