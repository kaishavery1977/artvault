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
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
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
                                // Glass edge so the circle picks up the ambient
                                // gradient behind it. Decoration only.
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
                            )
                            .animate(key: ValueKey('onboard_$i'))
                            .scale(
                              begin: const Offset(0.7, 0.7),
                              curve: Curves.easeOutBack,
                            ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: AppTheme.display(context),
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
