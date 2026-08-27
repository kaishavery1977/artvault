import 'package:flutter/material.dart';

/// Custom page transition that creates a 3D depth push effect.
/// The outgoing page slides back while the incoming page slides forward,
/// with a perspective tilt that creates a layered depth feel.
class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PremiumPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
            children: [
              // Outgoing page slides back with fade
              AnimatedBuilder(
                animation: reverseCurved,
                builder: (context, _) {
                  final t = reverseCurved.value;
                  // ignore: deprecated_member_use
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    // ignore: deprecated_member_use
                    ..translate(0.0, 0.0, -100 * t)
                    // ignore: deprecated_member_use
                    ..scale(1.0 - 0.1 * t);
                  return Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: Opacity(
                      opacity: 1.0 - t,
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  );
                },
              ),
              // Incoming page slides forward with scale
              AnimatedBuilder(
                animation: curved,
                builder: (context, _) {
                  final t = curved.value;
                  // ignore: deprecated_member_use
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    // ignore: deprecated_member_use
                    ..translate(0.0, 50 * (1 - t), 80 * (1 - t))
                    // ignore: deprecated_member_use
                    ..scale(0.92 + 0.08 * t);
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

/// Slide-from-bottom with depth effect (for modals and sheets).
class PremiumSlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PremiumSlideUpRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final t = curved.value;
              // ignore: deprecated_member_use
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                // ignore: deprecated_member_use
                ..translate(0.0, 200 * (1 - t), 50 * (1 - t))
                // ignore: deprecated_member_use
                ..scale(0.9 + 0.1 * t);
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: transform,
                child: Opacity(opacity: t, child: child),
              );
            },
          );
        },
      );
}

/// Fade + scale for dialogs
class PremiumDialogRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PremiumDialogRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );

          return AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final t = curved.value;
              // ignore: deprecated_member_use
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                // ignore: deprecated_member_use
                ..scale(t);
              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              );
            },
          );
        },
      );
}
