import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/gallery_link_reminder_service.dart';
import '../../core/services/resume_intro.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Cinematic branded launch screen on pure black.
///
/// Cold starts play the full staged intro — palette icon with purple glow
/// blooms on black, a shockwave ring lands, the mark drops in with a
/// rotation settle, the wordmark reveals letter-by-letter with a gold
/// shimmer sweep, the tagline drifts up, then pulsing dots hand off to
/// the next screen with a smooth fade. Returning from the background
/// replays a shorter, punchier cut (glow + ring + logo only, no wordmark)
/// so frequent app switches feel fast but still premium. Everything is
/// transform/opacity only (no blur), so it stays smooth on budget phones.
/// Reduced motion renders the mark statically and hands off immediately.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _exit;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  static const Duration _introFull = Duration(milliseconds: 3400);
  static const Duration _introResume = Duration(milliseconds: 1100);
  static const Duration _introReduced = Duration(milliseconds: 350);
  static const Duration _exitHoldFull = Duration(milliseconds: 560);

  late final bool _resumeReplay;

  @override
  void initState() {
    super.initState();
    _resumeReplay = ResumeIntro.isResumeReplay;
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _exitScale = CurvedAnimation(parent: _exit, curve: Curves.easeInCubic);
    _exitOpacity = CurvedAnimation(parent: _exit, curve: Curves.easeIn);
    _start();
  }

  Future<void> _start() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final present = reducedMotion
        ? _introReduced
        : (_resumeReplay ? _introResume : _introFull);

    final boot = ref.read(authProvider.notifier).bootstrap();
    await Future.wait([boot, Future<void>.delayed(present)]);
    if (!mounted) return;

    final state = ref.read(authProvider);
    if (state.status == AuthStatus.authenticated) {
      unawaited(
        GalleryLinkReminderService.instance.check(state.user?.uid ?? ''),
      );
    }
    final resume = ResumeIntro.consume();

    String target;
    if (state.status == AuthStatus.authenticated) {
      final appLock =
          SettingsRepository.instance.appLockEnabled ||
          await AuthRepository.instance.biometricEnabled ||
          await AuthRepository.instance.faceLockEnabled ||
          await AuthRepository.instance.passcodeSet;
      target = appLock ? '/lock' : (resume ?? '/home');
    } else {
      target = resume ?? '/onboarding';
    }
    if (!mounted) return;

    if (reducedMotion) {
      context.go(target);
      return;
    }

    _exit.forward();
    await Future<void>.delayed(_exitHoldFull);
    if (!mounted) return;
    context.go(target);
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    final mark = _LogoMark();
    final Widget content;
    if (reducedMotion) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(height: AppSpacing.xl),
          Text(
            'ArtVault',
            style: AppTheme.display(context, size: 40).copyWith(color: fg),
          ),
        ],
      );
    } else if (_resumeReplay) {
      // Resume replay: glow + shockwave ring + logo settle.
      // No wordmark or tagline — quick and punchy.
      content = SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Purple radial glow bloom.
            _GlowOrb()
                .animate()
                .scaleXY(
                  begin: 0.25,
                  end: 1,
                  duration: 600.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 450.ms)
                .then()
                .fadeOut(delay: 200.ms, duration: 600.ms),
            // Expanding shockwave ring.
            Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.8),
                      width: 3,
                    ),
                  ),
                )
                .animate(delay: 150.ms)
                .scaleXY(
                  begin: 0.45,
                  end: 1.65,
                  duration: 700.ms,
                  curve: Curves.easeOutCubic,
                )
                .then()
                .fadeOut(duration: 220.ms),
            // Logo tile drops in with rotation settle.
            _LogoMark()
                .animate(delay: 100.ms)
                .scaleXY(
                  begin: 0.4,
                  end: 1,
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                )
                .rotate(
                  begin: -0.12,
                  end: 0,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 400.ms),
          ],
        ),
      );
    } else {
      // Cold start: full choreography on black — glow, shockwave ring,
      // logo settle, staggered wordmark, tagline, pulsing dots.
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage 1 + 2: purple glow blooms, shockwave ring, logo settles.
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Purple radial glow blooming open.
                _GlowOrb()
                    .animate()
                    .scaleXY(
                      begin: 0.25,
                      end: 1,
                      duration: 1000.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 700.ms)
                    .then()
                    .fadeOut(delay: 600.ms, duration: 1400.ms),
                // Shockwave ring expanding outward.
                Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.8),
                          width: 3,
                        ),
                      ),
                    )
                    .animate(delay: 350.ms)
                    .scaleXY(
                      begin: 0.45,
                      end: 1.65,
                      duration: 1300.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then()
                    .fadeOut(duration: 320.ms),
                // The logo tile itself.
                _LogoMark()
                    .animate(delay: 250.ms)
                    .scaleXY(
                      begin: 0.4,
                      end: 1,
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    )
                    .rotate(
                      begin: -0.12,
                      end: 0,
                      duration: 800.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 600.ms),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Stage 3: wordmark reveals letter-by-letter, gold shimmer sweep.
          _StaggeredWordmark(color: fg)
              .animate(delay: 1800.ms)
              .shimmer(
                duration: 1200.ms,
                color: AppColors.accent.withValues(alpha: 0.45),
              ),
          const SizedBox(height: AppSpacing.xs),

          // Stage 4: tagline drifts up.
          Text(
            'Your Private Gallery',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: muted,
              letterSpacing: 1.4,
            ),
          )
              .animate(delay: 2000.ms)
              .slideY(begin: 0.3)
              .fadeIn(duration: 700.ms),
          const SizedBox(height: AppSpacing.xxl),

          // Stage 5: pulsing dot loader.
          _PulsingDots(color: fg)
              .animate(delay: 2300.ms)
              .fadeIn(duration: 400.ms),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(
          opacity: 1 - _exitOpacity.value,
          child: Transform.scale(
            scale: 1 + 0.06 * _exitScale.value,
            child: child,
          ),
        ),
        child: Center(child: content),
      ),
    );
  }
}

/// The 112×112 gradient logo tile with the palette glyph — shared by the
/// full choreography, the quick intro, and the static reduced-motion render.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.palette_rounded, size: 56, color: Colors.white),
    );
  }
}

/// Purple radial glow orb that blooms behind the logo on the black background.
class _GlowOrb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.40),
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
    );
  }
}

/// "ArtVault" revealed one letter at a time, sliding up from below.
class _StaggeredWordmark extends StatelessWidget {
  final Color color;
  const _StaggeredWordmark({required this.color});

  @override
  Widget build(BuildContext context) {
    const word = 'ArtVault';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < word.length; i++)
          Builder(
            builder: (context) {
              final letter = Text(
                word[i],
                style: AppTheme.display(context, size: 40).copyWith(
                  color: color,
                ),
              ).animate(delay: (900 + i * 90).ms);
              return letter
                  .slideY(begin: 0.6)
                  .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic);
            },
          ),
      ],
    );
  }
}

/// Three staggered pulsing dots — lighter-weight than a spinner.
class _PulsingDots extends StatelessWidget {
  final Color color;
  const _PulsingDots({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child:
                Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.8),
                      ),
                    )
                    .animate(
                      delay: (i * 160).ms,
                      onPlay: (controller) =>
                          controller.repeat(reverse: true),
                    )
                    .scaleXY(
                      begin: 0.5,
                      end: 1.15,
                      duration: 420.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scaleXY(
                      end: 0.5,
                      duration: 420.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
      ],
    );
  }
}
