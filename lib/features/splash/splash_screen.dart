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

/// Branded launch screen with a cinematic fade-in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
    _start();
  }

  Future<void> _start() async {
    // Restore session / check remember-me.
    await ref.read(authProvider.notifier).bootstrap();
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.status == AuthStatus.authenticated) {
      // App Lock gate (cold-start biometric / face / passcode lock on launch).
      final appLock =
          SettingsRepository.instance.appLockEnabled ||
          await AuthRepository.instance.biometricEnabled ||
          await AuthRepository.instance.faceLockEnabled ||
          await AuthRepository.instance.passcodeSet;
      if (!mounted) return;
      context.go(appLock ? '/lock' : '/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      // Transparent so the ambient gradient shows through the launch screen.
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 900.ms),
              const SizedBox(height: AppSpacing.xl),
              Text(
                    'ArtVault',
                    style: AppTheme.display(
                      context,
                      size: 40,
                    ).copyWith(color: fg),
                  )
                  .animate()
                  .slideY(begin: 0.2)
                  .fadeIn(duration: 800.ms, delay: 250.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your Private Gallery',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: (isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted),
                  letterSpacing: 1.4,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
              const SizedBox(height: AppSpacing.xxl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
