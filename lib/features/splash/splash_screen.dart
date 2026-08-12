import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Cinematic branded launch screen.
///
/// Plays a staged "video" intro — a spotlight blooms behind the logo,
/// the mark drops in with a rotation settle, the wordmark reveals
/// letter-by-letter with a gold shimmer sweep, then a pulsing dot loader
/// hands off to the next screen with a camera-push exit. Everything is
/// transform/opacity only (no blur), so it stays smooth on budget phones.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// Exit choreography: content pushes slightly toward the camera (scale up)
  /// while fading, then the router hand-off takes over. Feels continuous.
  late final AnimationController _exit;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  /// Total intro runtime before the hand-off starts.
  static const Duration _introDuration = Duration(milliseconds: 3400);

  @override
  void initState() {
    super.initState();
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
    // Restore session / check remember-me while the intro plays, so the
    // animation is never gated on the network.
    final boot = ref.read(authProvider.notifier).bootstrap();
    await Future.wait([
      boot,
      Future<void>.delayed(_introDuration),
    ]);
    if (!mounted) return;

    final state = ref.read(authProvider);
    String target;
    if (state.status == AuthStatus.authenticated) {
      // App Lock gate (cold-start biometric / face / passcode lock on launch).
      final appLock =
          SettingsRepository.instance.appLockEnabled ||
          await AuthRepository.instance.biometricEnabled ||
          await AuthRepository.instance.faceLockEnabled ||
          await AuthRepository.instance.passcodeSet;
      target = appLock ? '/lock' : '/home';
    } else {
      target = '/onboarding';
    }
    if (!mounted) return;

    // Camera-push exit, then hand off to the next screen.
    _exit.forward();
    await Future<void>.delayed(const Duration(milliseconds: 560));
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

    return Scaffold(
      // Transparent so the ambient gradient shows through the launch screen.
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(
          opacity: 1 - _exitOpacity.value,
          child: Transform.scale(
            scale: 1 + 0.06 * _exitScale.value,
            child: child,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =============================================================
              // Stage 1 + 2 — spotlight blooms, logo drops in with a settle.
              // =============================================================
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft gold spotlight blooming open behind the mark.
                    _Spotlight()
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
                    // Expanding shockwave ring, like a stamp landing.
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.45),
                          width: 2,
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
                        .fadeOut(duration: 1300.ms),
                    // The logo tile itself.
                    Container(
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
                      child: const Icon(
                        Icons.palette,
                        size: 56,
                        color: Colors.white,
                      ),
                    )
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

              // =============================================================
              // Stage 3 — wordmark reveals letter-by-letter, then a gold
              // shimmer sweeps across the settled text.
              // =============================================================
              _StaggeredWordmark(color: fg)
                  .animate(delay: 1800.ms)
                  .shimmer(
                    duration: 1200.ms,
                    color: AppColors.accent.withValues(alpha: 0.45),
                  ),
              const SizedBox(height: AppSpacing.xs),

              // =============================================================
              // Stage 4 — tagline drifts up.
              // =============================================================
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

              // =============================================================
              // Stage 5 — pulsing dot loader.
              // =============================================================
              _PulsingDots(color: fg).animate(
                delay: 2300.ms,
              ).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expanding radial glow behind the logo — "stage lights" coming up.
class _Spotlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.30),
            AppColors.accent.withValues(alpha: 0),
          ],
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
          Text(
            word[i],
            style: AppTheme.display(context, size: 40).copyWith(color: color),
          )
              .animate(delay: (900 + i * 90).ms)
              .slideY(begin: 0.6)
              .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic),
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
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.8),
              ),
            )
                .animate(
                  delay: (i * 160).ms,
                  onPlay: (controller) => controller.repeat(reverse: true),
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
