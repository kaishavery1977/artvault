import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/settings_repository.dart';

/// Three-panel welcome experience introducing the vault's value.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.palette,
      title: 'Curate Your Collection',
      body:
          'Photograph, catalogue and treasure every painting you own in a single elegant private gallery.',
    ),
    (
      icon: Icons.auto_awesome,
      title: 'AI-Powered Insight',
      body:
          'Automatic tagging, duplicate detection and smart analytics surface the story behind your art.',
    ),
    (
      icon: Icons.verified_user,
      title: 'Secure & Offline-First',
      body:
          'Biometric lock, encrypted storage and full offline access. Your collection, always with you.',
    ),
  ];

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    // Mark done + hand off immediately; persistence is fire-and-forget and
    // best-effort (worst case: onboarding plays again on the next launch).
    ref.read(onboardedProvider.notifier).state = true;
    context.go('/login');
    unawaited(SettingsRepository.instance.setOnboarded().catchError((_) {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  final first = i == 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // The emblem. On the first slide it opens cinematically
                        // — glow bloom, expanding ring, badge settle — echoing
                        // the splash's intro so the camera-push exit hands off
                        // into it as one continuous shot. Under reduced motion
                        // everything renders statically.
                        _SlideIcon(
                          slide: slide,
                          scheme: scheme,
                          cinematic: first,
                          animated: !reducedMotion,
                        ),
                        SizedBox(height: context.adaptiveSpace(AppSpacing.xxl)),
                        // Title drifts up behind the emblem, then the body
                        // follows — the same cascade the splash uses.
                        _Reveal(
                          delay: first
                              ? const Duration(milliseconds: 450)
                              : Duration.zero,
                          slideY: first ? 0.22 : 0.0,
                          duration: 700.ms,
                          child: Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: AppTheme.display(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Reveal(
                          delay: first
                              ? const Duration(milliseconds: 700)
                              : Duration.zero,
                          slideY: first ? 0.1 : 0.0,
                          duration: 750.ms,
                          child: Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  height: 1.5,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: _page == _slides.length - 1 ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Applies the slide's cascade (drift up + fade) unless animations are
/// disabled, in which case the child renders statically.
class _Reveal extends StatelessWidget {
  final Duration delay;
  final double slideY;
  final Duration duration;
  final Widget child;

  const _Reveal({
    required this.delay,
    required this.slideY,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: delay)
        .slideY(begin: slideY)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic);
  }
}

/// A slide's emblem. On the first slide it opens cinematically — a soft glow
/// blooms, a thin ring expands like the splash's shockwave, then the badge
/// settles in — so the splash's camera-push exit hands off into it seamlessly.
/// Later slides just settle the badge in. With [animated] false (reduced
/// motion) the badge renders statically.
class _SlideIcon extends StatelessWidget {
  final ({IconData icon, String title, String body}) slide;
  final ColorScheme scheme;
  final bool cinematic;
  final bool animated;

  const _SlideIcon({
    required this.slide,
    required this.scheme,
    required this.cinematic,
    required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        shape: BoxShape.circle,
        // Glass edge so the circle picks up the ambient gradient behind it.
        // Decoration only.
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.10),
          width: 0.6,
        ),
      ),
      child: Icon(slide.icon, size: 64, color: scheme.primary),
    );

    if (!animated) return badge;

    if (!cinematic) {
      return badge
          .animate(key: ValueKey('onboard_${slide.title}'))
          .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack);
    }

    // First slide: glow + ring + settle, echoing the splash's intro.
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft radial glow blooming open behind the badge.
          Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.20),
                      scheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              )
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1,
                duration: 1000.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(duration: 700.ms)
              .then()
              .fadeOut(delay: 500.ms, duration: 1100.ms),
          // Expanding ring — the splash's stamp shockwave, replayed softly.
          Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              )
              .animate(delay: 250.ms)
              .scaleXY(
                begin: 0.7,
                end: 1.5,
                duration: 1200.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(duration: 1200.ms),
          // The badge itself, dropping in with a settle.
          badge
              .animate(key: ValueKey('onboard_${slide.title}'), delay: 100.ms)
              .scaleXY(
                begin: 0.55,
                end: 1,
                duration: 800.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 650.ms),
        ],
      ),
    );
  }
}
