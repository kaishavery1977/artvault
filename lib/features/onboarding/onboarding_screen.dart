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
    SettingsRepository.instance.setOnboarded();
    ref.read(onboardedProvider.notifier).state = true;
    context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                        // into it as one continuous shot.
                        _SlideIcon(
                          slide: slide,
                          scheme: scheme,
                          cinematic: first,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // Title drifts up behind the emblem, then the body
                        // follows — the same cascade the splash uses.
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: AppTheme.display(context),
                        )
                            .animate(
                              delay: first
                                  ? const Duration(milliseconds: 260)
                                  : Duration.zero,
                            )
                            .slideY(begin: first ? 0.22 : 0.0)
                            .fadeIn(
                              duration: 460.ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.5,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                        )
                            .animate(
                              delay: first
                                  ? const Duration(milliseconds: 400)
                                  : Duration.zero,
                            )
                            .slideY(begin: first ? 0.1 : 0.0)
                            .fadeIn(
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
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

/// A slide's emblem. On the first slide it opens cinematically — a soft glow
/// blooms, a thin ring expands like the splash's shockwave, then the badge
/// settles in — so the splash's camera-push exit hands off into it seamlessly.
/// Later slides just settle the badge in.
class _SlideIcon extends StatelessWidget {
  final ({IconData icon, String title, String body}) slide;
  final ColorScheme scheme;
  final bool cinematic;

  const _SlideIcon({
    required this.slide,
    required this.scheme,
    required this.cinematic,
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
      child: Icon(
        slide.icon,
        size: 64,
        color: scheme.primary,
      ),
    );

    if (!cinematic) {
      return badge
          .animate(key: ValueKey('onboard_${slide.title}'))
          .scale(
            begin: const Offset(0.7, 0.7),
            curve: Curves.easeOutBack,
          );
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
                duration: 620.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(duration: 420.ms)
              .then()
              .fadeOut(delay: 320.ms, duration: 700.ms),
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
              .animate(delay: 140.ms)
              .scaleXY(
                begin: 0.7,
                end: 1.5,
                duration: 820.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(duration: 820.ms),
          // The badge itself, dropping in with a settle.
          badge
              .animate(
                key: ValueKey('onboard_${slide.title}'),
                delay: 40.ms,
              )
              .scaleXY(
                begin: 0.55,
                end: 1,
                duration: 560.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 420.ms),
        ],
      ),
    );
  }
}
