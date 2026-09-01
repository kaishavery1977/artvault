import 'package:flutter/foundation.dart' show kIsWeb;
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

  static Duration get _introFull => kIsWeb 
      ? const Duration(milliseconds: 5500)
      : const Duration(milliseconds: 3000);
  static const Duration _introResume = Duration(milliseconds: 900);
  static const Duration _introReduced = Duration(milliseconds: 150);
  static Duration get _exitHoldFull => kIsWeb 
      ? const Duration(milliseconds: 600)
      : const Duration(milliseconds: 350);

  late final bool _resumeReplay;

  @override
  void initState() {
    super.initState();
    _resumeReplay = ResumeIntro.isResumeReplay;
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 200),
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
      final appLock = kIsWeb ? false : (
          SettingsRepository.instance.appLockEnabled ||
          await AuthRepository.instance.biometricEnabled ||
          await AuthRepository.instance.faceLockEnabled ||
          await AuthRepository.instance.passcodeSet);
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
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 250.ms)
                .then()
                .fadeOut(delay: 100.ms, duration: 300.ms),
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
                .animate(delay: 80.ms)
                .scaleXY(
                  begin: 0.45,
                  end: 1.65,
                  duration: 450.ms,
                  curve: Curves.easeOutCubic,
                )
                .then()
                .fadeOut(duration: 150.ms),
            // Logo tile drops in with rotation settle.
            _LogoMark()
                .animate(delay: 50.ms)
                .scaleXY(
                  begin: 0.4,
                  end: 1,
                  duration: 350.ms,
                  curve: Curves.easeOutBack,
                )
                .rotate(
                  begin: -0.12,
                  end: 0,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 250.ms),
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
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 500.ms)
                    .then()
                    .fadeOut(delay: 500.ms, duration: 800.ms),
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
                    .animate(delay: 120.ms)
                    .scaleXY(
                      begin: 0.45,
                      end: 1.65,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then()
                    .fadeOut(duration: 400.ms),
                // The logo tile itself.
                _LogoMark()
                    .animate(delay: 80.ms)
                    .scaleXY(
                      begin: 0.4,
                      end: 1,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    )
                    .rotate(
                      begin: -0.12,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 600.ms),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Stage 3: wordmark reveals letter-by-letter, gold shimmer sweep.
          _StaggeredWordmark(color: fg)
              .animate(delay: kIsWeb ? 2200.ms : 1000.ms)
              .shimmer(
                duration: 1000.ms,
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
              .animate(delay: kIsWeb ? 3200.ms : 1400.ms)
              .slideY(begin: 0.25)
              .fadeIn(duration: 600.ms),
          const SizedBox(height: AppSpacing.xxl),

          // Stage 5: pulsing dot loader.
          _PulsingDots(color: fg)
              .animate(delay: kIsWeb ? 4000.ms : 1700.ms)
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
        child: Stack(
          children: [
            Center(child: content),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32 + MediaQuery.paddingOf(context).bottom,
              child: _SplashFooter(reducedMotion: reducedMotion),
            ),
          ],
        ),
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
              ).animate(delay: (i * 60).ms);
              return letter
                  .slideY(begin: 0.6)
                  .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic);
            },
          ),
      ],
    );
  }
}

/// Professional footer — "Crafted by Kais Havery" — with glowing text,
/// animated gradient divider, and sparkle accents.
class _SplashFooter extends StatefulWidget {
  final bool reducedMotion;
  const _SplashFooter({required this.reducedMotion});

  @override
  State<_SplashFooter> createState() => _SplashFooterState();
}

class _SplashFooterState extends State<_SplashFooter>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _sparkleCtrl;

  @override
  void initState() {
    super.initState();      _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    if (!widget.reducedMotion) {
      // Delay start so it plays after the intro lands.
      Future.delayed(kIsWeb ? 3500.ms : 1800.ms, () {
        if (mounted) {
          _glowCtrl.repeat(reverse: true);
          _sparkleCtrl.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _StaticDivider(),
          SizedBox(height: 12),
          _StaticBy(),
          SizedBox(height: 4),
          _StaticSub(),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated gradient divider
        _AnimatedDivider(ctrl: _glowCtrl)
            .animate(delay: kIsWeb ? 4200.ms : 1800.ms)
            .fadeIn(duration: 600.ms)
            .scaleX(begin: 0, end: 1, curve: Curves.easeOutCubic),
        const SizedBox(height: 18),
        // Glowing name row with sparkle
        _GlowingBy(glowCtrl: _glowCtrl, sparkleCtrl: _sparkleCtrl)
            .animate(delay: kIsWeb ? 4400.ms : 1900.ms)
            .fadeIn(duration: 700.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),
        const SizedBox(height: 10),
        // Tagline
        Text(
          'Made with passion for art collectors',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.40),
          ),
        ).animate(delay: kIsWeb ? 4700.ms : 2100.ms).fadeIn(duration: 600.ms),
      ],
    );
  }
}

/// Animated gradient divider that pulses width + glow.
class _AnimatedDivider extends StatelessWidget {
  final AnimationController ctrl;
  const _AnimatedDivider({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) {
        final t = ctrl.value;
        final w = 64 + 14 * t; // 64→78→64
        final alpha = 0.18 + 0.14 * t;
        return Container(
          width: w,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: alpha),
                Colors.white.withValues(alpha: alpha * 1.2),
                AppColors.accent.withValues(alpha: alpha),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: alpha * 0.6),
                blurRadius: 10 + 4 * t,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Crafted by" row with glowing name + rotating sparkle dots.
class _GlowingBy extends StatelessWidget {
  final AnimationController glowCtrl;
  final AnimationController sparkleCtrl;
  const _GlowingBy({required this.glowCtrl, required this.sparkleCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glowCtrl, sparkleCtrl]),
      builder: (_, _) {
        final g = glowCtrl.value;
        final s = sparkleCtrl.value;
        final glowAlpha = 0.55 + 0.35 * g; // 0.55→0.9
        final glowSpread = 2.0 + 3.0 * g;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left sparkle
            _SparkleDot(phase: s, offset: 0),
            const SizedBox(width: 10),
            Icon(
              Icons.favorite_rounded,
              size: 14,
              color: AppColors.accent.withValues(alpha: 0.7 + 0.2 * g),
            ),
            const SizedBox(width: 8),
            // Glowing name
            Text(
              'Crafted by ',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.50),
              ),
            ),
            Text(
              'Kais Havery',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
                color: AppColors.accent.withValues(alpha: glowAlpha),
                shadows: [
                  Shadow(
                    color: AppColors.accent.withValues(alpha: glowAlpha * 0.7),
                    blurRadius: glowSpread * 1.5,
                  ),
                  Shadow(
                    color: AppColors.accent.withValues(alpha: glowAlpha * 0.4),
                    blurRadius: glowSpread * 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right sparkle
            _SparkleDot(phase: s, offset: 0.5),
          ],
        );
      },
    );
  }
}

/// Tiny rotating sparkle dot.
class _SparkleDot extends StatelessWidget {
  final double phase; // 0..1
  final double offset; // offset to desync left/right
  const _SparkleDot({required this.phase, required this.offset});

  @override
  Widget build(BuildContext context) {
    final t = ((phase + offset) % 1.0);
    final pulse = (t < 0.5) ? t * 2 : 2 - t * 2; // triangle wave 0→1→0
    final size = 5.0 + 3.0 * pulse;
    final alpha = 0.3 + 0.6 * pulse;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: alpha),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: alpha * 0.6),
            blurRadius: 6 * pulse,
          ),
        ],
      ),
    );
  }
}

/// Static divider for reduced-motion mode.
class _StaticDivider extends StatelessWidget {
  const _StaticDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 1.5,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

/// Static by-line for reduced-motion mode.
class _StaticBy extends StatelessWidget {
  const _StaticBy();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_rounded, size: 14, color: AppColors.accent.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text('Crafted by Kais Havery', style: TextStyle(fontSize: 16, letterSpacing: 1.8, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.65))),
      ],
    );
  }
}

/// Static subtext for reduced-motion mode.
class _StaticSub extends StatelessWidget {
  const _StaticSub();
  @override
  Widget build(BuildContext context) {
    return Text('Made with passion for art collectors', style: TextStyle(fontSize: 13, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.40)));
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
                      delay: (i * 100).ms,
                      onPlay: (controller) =>
                          controller.repeat(reverse: true),
                    )
                    .scaleXY(
                      begin: 0.5,
                      end: 1.15,
                      duration: 350.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scaleXY(
                      end: 0.5,
                      duration: 350.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
      ],
    );
  }
}
