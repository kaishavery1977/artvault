import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';

/// Full-screen celebration shown after a successful Pro purchase: a burst of
/// brand-colored confetti behind a glass card that springs in. Ticker-only
/// (no timers), so tests that end mid-flight stay clean, and reduced motion
/// renders the card statically without the confetti stream.
Future<void> showProCelebration(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Pro unlocked',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, _) => const _ProCelebration(),
  );
}

class _ProCelebration extends StatefulWidget {
  const _ProCelebration();

  @override
  State<_ProCelebration> createState() => _ProCelebrationState();
}

class _ProCelebrationState extends State<_ProCelebration>
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
              colors: const [
                Color(0xFF8AB4F8),
                Color(0xFFF59E0B),
                Color(0xFF34D399),
                Color(0xFFF472B6),
                Color(0xFFA78BFA),
              ],
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
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 40,
                  ),
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
                  text: 'Welcome to Pro!',
                  style: AppTheme.display(context, size: 24),
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                  duration: const Duration(milliseconds: 1300),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Unlimited capacity, gallery analytics and watermarking '
                  'are now unlocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Tap anywhere to continue',
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
