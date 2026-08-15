import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/settings_repository.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String appVersion = '0.1.0';
  static const String appBuild = '1';

  static const String engineLabel = 'Flutter 3.44.8 · Dart 3.12';

  static const _features = <(IconData, String)>[
    (Icons.offline_pin_outlined, 'Offline-first vault'),
    (Icons.cloud_done_outlined, 'Cloud sync & backup'),
    (Icons.fact_check_outlined, 'Duplicate detection'),
    (Icons.qr_code_2, 'QR identification'),
    (Icons.description_outlined, 'Provenance documents'),
    (Icons.link, 'Public gallery links'),
    (Icons.ios_share, 'Catalogue export'),
    (Icons.fingerprint, 'App lock & biometrics'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final paintings = ref.watch(paintingsProvider).valueOrNull?.length ?? 0;
    final artists = ref.watch(artistsProvider).valueOrNull?.length ?? 0;
    final documents = ref.watch(documentsProvider).valueOrNull?.length ?? 0;
    final plan = ref.watch(authProvider).user?.plan ?? AppPlan.free;

    final children = staggerReveal(
      [
        // ------------------------------------------------------------------
        // HERO — logo tile, shimmering wordmark, tagline, version pill
        // ------------------------------------------------------------------
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
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
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
            text: AppConstants.appName,
            style: AppTheme.display(context, size: 26),
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
            duration: const Duration(milliseconds: 1300),
          ),
        ),
        Center(
          child: Text(
            AppConstants.appTagline,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
              color: scheme.primary.withValues(alpha: 0.07),
            ),
            child: Text(
              'Version $appVersion ($appBuild)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ------------------------------------------------------------------
        // LIVE VAULT STATS
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              _StatTile(
                icon: Icons.brush_outlined,
                label: 'Paintings',
                value: paintings,
              ),
              _divider(scheme),
              _StatTile(
                icon: Icons.person_outline,
                label: 'Artists',
                value: artists,
              ),
              _divider(scheme),
              _StatTile(
                icon: Icons.description_outlined,
                label: 'Documents',
                value: documents,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ------------------------------------------------------------------
        // ABOUT
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle(context, Icons.auto_awesome_outlined, 'About'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ArtVault is a private digital gallery for collectors, curators '
                'and galleries. Every artwork lives on-device first, with '
                'optional encrypted cloud sync, smart duplicate detection, '
                'QR identification, provenance documents and full catalogue '
                'export — so your collection is organised, analysed and '
                'protected wherever you are.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: scheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ------------------------------------------------------------------
        // FEATURES
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle(context, Icons.workspace_premium_outlined, 'Capabilities'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (icon, label) in _features)
                    _featureChip(context, icon, label),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ------------------------------------------------------------------
        // TECHNICAL DETAILS
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            children: [
              _infoRow(context, 'Version', '$appVersion ($appBuild)'),
              _infoRow(context, 'Engine', engineLabel),
              _infoRow(context, 'Platforms', 'Android · iOS'),
              _infoRow(context, 'Data model', 'Offline-first · Firebase optional'),
              _infoRow(context, 'Plan', plan.isPro ? 'Pro' : 'Free'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ------------------------------------------------------------------
        // CELEBRATIONS (transparency)
        // ------------------------------------------------------------------
        const _CelebrationsCard(),
        const SizedBox(height: AppSpacing.lg),

        // ------------------------------------------------------------------
        // LEGAL
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle(context, Icons.gavel_outlined, 'Legal'),
              const SizedBox(height: AppSpacing.xs),
              _link(context, 'Privacy policy', () => _launch('https://example.com/privacy')),
              _link(context, 'Terms of service', () => _launch('https://example.com/terms')),
              _link(context, 'Licences', () => _launch('https://example.com/licenses')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ------------------------------------------------------------------
        // FOOTER — credit signature + closing line
        // ------------------------------------------------------------------
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
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
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

  static Widget _cardTitle(BuildContext context, IconData icon, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }

  static Widget _featureChip(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        color: scheme.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static Widget _divider(ColorScheme scheme) {
    return Container(
      width: 1,
      height: 40,
      color: scheme.onSurface.withValues(alpha: 0.08),
    );
  }

  static Widget _infoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
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

/// A single vault-stat tile in the hero strip: icon + animated count + label.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 6),
          AnimatedCountUp(
            value: value.toDouble(),
            format: (v) => Formatters.number(v),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
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
          AboutScreen._cardTitle(
            context,
            Icons.celebration_outlined,
            'Celebrations',
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
