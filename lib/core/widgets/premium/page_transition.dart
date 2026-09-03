import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds a [CustomTransitionPage] with the app's shared 3D depth push
/// effect: the outgoing page recedes (scale down + fade) while the incoming
/// page advances (scale up from smaller + fade in), with perspective tilt.
///
/// This is the single source of truth for pushed-route transitions — every
/// top-level route in [GoRouter] (see `app_router.dart`) routes through it so
/// all screens share one motion language.
///
/// Reduced motion is honored end-to-end: when the platform (or the browser,
/// via `prefers-reduced-motion`) reports animations disabled, the route
/// swaps instantly with zero duration instead of playing the depth effect.
Page<void> depthPage(BuildContext context, Widget child) {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: reducedMotion
        ? Duration.zero
        : kIsWeb
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 280),
    reverseTransitionDuration: reducedMotion
        ? Duration.zero
        : kIsWeb
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Belt-and-braces: re-check at transition time so a motion-preference
      // change mid-flight is honored too, not only at route construction.
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final reverseCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      );

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Outgoing page recedes into the background.
          // IgnorePointer so it never blocks taps on the incoming page.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: reverseCurved,
              builder: (context, _) {
                final t = reverseCurved.value;
                // ignore: deprecated_member_use
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  // ignore: deprecated_member_use
                  ..translate(0.0, 0.0, -80 * t)
                  // ignore: deprecated_member_use
                  ..scale(1.0 - 0.08 * t);
                return Transform(
                  alignment: Alignment.center,
                  transform: transform,
                  child: Opacity(
                    opacity: 1.0 - t * 0.6,
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                );
              },
            ),
          ),
          // Incoming page advances from the foreground.
          AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final t = curved.value;
              // ignore: deprecated_member_use
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                // ignore: deprecated_member_use
                ..translate(0.0, 40 * (1 - t), 60 * (1 - t))
                // ignore: deprecated_member_use
                ..scale(0.93 + 0.07 * t);
              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: Opacity(opacity: t, child: child),
              );
            },
          ),
        ],
      );
    },
  );
}
