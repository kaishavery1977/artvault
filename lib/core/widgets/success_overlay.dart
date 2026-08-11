import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Full-screen animated confirmation shown when a lock method succeeds.
///
/// Shared by every unlock flow — fingerprint, passcode and face — so all
/// methods feel identical: a green checkmark springs in with a glow while the
/// message fades up, then the caller dismisses the route once the overlay has
/// been shown.
///
/// Must be placed inside a [Stack]; fills it entirely.
class SuccessCheckOverlay extends StatelessWidget {
  /// Drive this from 0 → 1 to animate the checkmark reveal.
  final Animation<double> animation;

  final String message;

  /// Optional secondary line under the message.
  final String? subtitle;

  /// Darkness of the scrim behind the confirmation.
  final double scrimOpacity;

  const SuccessCheckOverlay({
    super.key,
    required this.animation,
    required this.message,
    this.subtitle,
    this.scrimOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: scrimOpacity),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final v = Curves.elasticOut.transform(animation.value);
                    return Transform.scale(
                      scale: v,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.55),
                              blurRadius: 44,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 56,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  key: ValueKey(message),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(duration: 350.ms, delay: 150.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
