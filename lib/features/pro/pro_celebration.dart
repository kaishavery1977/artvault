import 'package:confetti/confetti.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';

/// Brand confetti palette shared across celebrations.
const List<Color> kCelebrationColors = [
  Color(0xFF8AB4F8),
  Color(0xFFF59E0B),
  Color(0xFF34D399),
  Color(0xFFF472B6),
  Color(0xFFA78BFA),
];

/// Reusable full-screen celebration: a burst of brand-colored confetti
/// behind a glass card that springs in, plus a haptic thump so the moment
/// feels physical. Ticker-only (no timers), so tests that end mid-flight
/// stay clean; reduced motion renders the card statically without confetti.
Future<void> showConfettiCelebration(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.workspace_premium,
  String? iconLabel,
  List<Color> colors = kCelebrationColors,
}) async {
  // Resolve the reduced-motion flag up front (no async gap), and kick the
  // haptic off without awaiting so the dialog shows instantly.
  final reduced = MediaQuery.disableAnimationsOf(context);
  if (!reduced) {
    // Haptics are best-effort — fire-and-forget, never block the dialog.
    unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
  }
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, _) => _CelebrationDialog(
      title: title,
      message: message,
      icon: icon,
      iconLabel: iconLabel,
      colors: colors,
    ),
  );
}

/// Shorthand for the Pro-unlock celebration (kept for call-site clarity).
Future<void> showProCelebration(BuildContext context) {
  return showConfettiCelebration(
    context,
    title: 'Welcome to Pro!',
    message: 'Unlimited capacity, gallery analytics and watermarking '
        'are now unlocked.',
    icon: Icons.workspace_premium,
    iconLabel: 'Pro unlocked',
  );
}

class _CelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? iconLabel;
  final List<Color> colors;

  const _CelebrationDialog({
    required this.title,
    required this.message,
    required this.icon,
    this.iconLabel,
    required this.colors,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        if (!reduced)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 60,
              gravity: 0.35,
              emissionFrequency: 0.05,
              shouldLoop: false,
              colors: widget.colors,
              strokeWidth: 1.4,
            ),
          ),
        Center(
          child: GlassCard(
            onTap: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 40),
                )
                    .animate(
                      onPlay: (c) => reduced ? c.stop() : c.forward(),
                    )
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.easeOutBack,
                      duration: 500.ms,
                    ),
                const SizedBox(height: AppSpacing.lg),
                GradientShimmerText(
                  text: widget.title,
                  style: AppTheme.display(context, size: 24),
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                  duration: const Duration(milliseconds: 1300),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.iconLabel ?? 'Tap anywhere to continue',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
