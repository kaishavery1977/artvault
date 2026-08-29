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

/// Clean branded launch screen — palette icon centered on pure black with
/// a purple glow that blooms and fades. On cold start the icon scales up
/// with a glow pulse, then the screen dissolves into the next route
/// (lock screen or home). Background resume replays a shorter, snappier
/// cut. Reduced motion skips straight to the next screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _exit;
  late final Animation<double> _exitOpacity;

  static const Duration _introFull = Duration(milliseconds: 2200);
  static const Duration _introResume = Duration(milliseconds: 900);
  static const Duration _introReduced = Duration(milliseconds: 200);
  static const Duration _exitDuration = Duration(milliseconds: 450);

  late final bool _resumeReplay;

  @override
  void initState() {
    super.initState();
    _resumeReplay = ResumeIntro.isResumeReplay;
    _exit = AnimationController(
      vsync: this,
      duration: _exitDuration,
    );
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

    // Smooth fade-out into the next screen.
    _exit.forward();
    await Future<void>.delayed(_exitDuration);
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
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final iconSize = 112.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(
          opacity: 1 - _exitOpacity.value,
          child: child,
        ),
        child: Center(
          child: reducedMotion
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlowingIcon(size: iconSize),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'ArtVault',
                      style: AppTheme.display(context, size: 36).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : (_resumeReplay
                  ? _GlowingIcon(size: iconSize)
                      .animate()
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .fadeIn(duration: 300.ms)
                  : _buildColdStart()),
        ),
      ),
    );
  }

  Widget _buildColdStart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon scales up from small with a glow bloom.
        _GlowingIcon(size: 112)
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 900.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 600.ms),
        const SizedBox(height: AppSpacing.xl),
        // Wordmark fades in after icon settles.
        Text(
          'ArtVault',
          style: AppTheme.display(context, size: 36).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        )
            .animate(delay: 700.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.15, duration: 500.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

/// Palette icon tile with a radial purple glow behind it.
/// The glow pulses gently while visible, then fades with the screen.
class _GlowingIcon extends StatelessWidget {
  final double size;
  const _GlowingIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.2,
      height: size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Purple radial glow
          Container(
            width: size * 2,
            height: size * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          )
              .animate(
                onPlay: (c) =>
                    MediaQuery.disableAnimationsOf(context)
                        ? c.stop()
                        : c.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1.08, 1.08),
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),
          // The palette icon tile
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.secondary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(
              Icons.palette_rounded,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
