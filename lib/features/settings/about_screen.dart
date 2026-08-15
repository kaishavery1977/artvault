import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/repositories/settings_repository.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = staggerReveal(
      [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.55)],
              ),
            ),
            child: const Icon(Icons.museum, size: 44, color: Colors.white),
          )
              .animate(key: const ValueKey('about-logo'))
              .scale(
                begin: const Offset(0.6, 0.6),
                curve: Curves.easeOutBack,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: GradientShimmerText(
            text: 'ArtVault',
            style: AppTheme.display(context, size: 26),
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
            duration: const Duration(milliseconds: 1300),
          ),
        ),
        Center(
          child: Text(
            'Your Private Gallery',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            children: [
              _infoRow(context, 'Version', '1.0.0'),
              _infoRow(context, 'Engine', 'Flutter 3.44 / Dart 3.12'),
              _infoRow(context, 'Platforms', 'Android · iOS'),
              _infoRow(context, 'Data', 'Offline-first · Firebase optional'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ArtVault helps private collectors, curators and galleries organise, '
                'analyse and protect their art. Every artwork is stored on-device first '
                'with optional encrypted cloud sync, duplicate detection, QR identification, '
                'provenance documents and full catalogue export.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CelebrationsCard(),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Legal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: AppSpacing.xs),
              _link(context, 'Privacy policy', () => _launch('https://example.com/privacy')),
              _link(context, 'Terms of service', () => _launch('https://example.com/terms')),
              _link(context, 'Licences', () => _launch('https://example.com/licenses')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text(
            'Crafted with care for art lovers.',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
              ),
              color: scheme.primary.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.brush, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                // The credit shimmers in brand colors — a small signature
                // moment at the end of the page.
                GradientShimmerText(
                  text: 'Built by Kais Havery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                  duration: const Duration(milliseconds: 1200),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'Every masterpiece starts with a single brushstroke.',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      initialDelay: const Duration(milliseconds: 60),
      interval: const Duration(milliseconds: 70),
      context: context,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About ArtVault')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: children,
      ),
    );
  }

  static Widget _infoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55))),
          ),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static Widget _link(BuildContext context, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: onTap,
    );
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Transparency list of every celebration that has fired (Pro unlock,
/// gallery published) with the date it happened. Reads the persisted history
/// so users can see which moments were celebrated and when.
class _CelebrationsCard extends StatelessWidget {
  const _CelebrationsCard();

  static const _labels = <String, String>{
    'pro-unlock': 'Pro unlocked',
    'gallery-published': 'Gallery published',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = SettingsRepository.instance.celebrationHistory;

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Celebrations',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (history.isEmpty)
            Text(
              'Nothing celebrated yet — moments like unlocking Pro or '
              'publishing a gallery will appear here.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            for (final entry in history) ...[
              _CelebrationRow(entry: entry),
              const Divider(
                height: 1,
                indent: 16,
                color: Color(0x0D000000),
              ),
            ],
        ],
      ),
    );
  }
}

class _CelebrationRow extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _CelebrationRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = (entry['id'] as String?) ?? 'unknown';
    final at = (entry['at'] as num?)?.toInt() ?? 0;
    final label = _CelebrationsCard._labels[id] ?? id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: const Icon(
              Icons.celebration_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            Formatters.dateTime(
              at == 0 ? null : DateTime.fromMillisecondsSinceEpoch(at),
            ),
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
