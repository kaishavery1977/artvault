import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Centers list-heavy content in a comfortable reading column on wide web
/// screens, so Settings-style rows and Documents tiles don't stretch
/// wall-to-wall on desktop.
///
/// Below the [maxWidth] (or on non-web platforms) it passes [child] through
/// untouched, so mobile and narrow layouts are byte-identical.
class WebContentColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebContentColumn({super.key, required this.child, this.maxWidth = 960});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: maxWidth, child: child),
        );
      },
    );
  }
}
