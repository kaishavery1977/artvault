import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/share_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/settings_repository.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// Version metadata lives in [AppConstants] so the About screen and the
  /// Settings footer share one source of truth (no drift on release bumps).
  static const String appVersion = AppConstants.appVersion;
  static const String appBuild = AppConstants.appBuild;

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
    (Icons.verified_user, 'Role-based access'),
    (Icons.workspace_premium_outlined, 'Pro billing & upgrades'),
    (Icons.celebration_outlined, 'Celebrations & confetti'),
    (Icons.history, '6-month condition reminders'),
    (Icons.restore, 'Full vault cloud restore'),
    (Icons.photo_library_outlined, 'Image repair & recovery'),
    (Icons.water_drop_outlined, 'Gallery link expiry & reminders'),
    (Icons.price_check, 'Price history tracking'),
    (Icons.map_outlined, 'Location & provenance map'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allPaintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final active = allPaintings.where((p) => !p.isDeleted).toList();
    final paintings = active.length;
    final artists = ref.watch(artistsProvider).valueOrNull?.length ?? 0;
    final documents = ref.watch(documentsProvider).valueOrNull?.length ?? 0;
    final storedImages = active.fold<int>(0, (sum, p) => sum + p.images.length);
    final vaultBytes = ref.watch(storageUsageProvider).valueOrNull?.total ?? 0;
    final plan =
        ref.watch(authProvider.select((a) => a.user))?.plan ?? AppPlan.free;

    final children = staggerReveal(
      [
        // ------------------------------------------------------------------
        // HERO — logo tile, shimmering wordmark, tagline, version pill
        // ------------------------------------------------------------------
        Center(
          child:
              Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.55),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(
                            alpha: isDark ? 0.35 : 0.25,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.museum,
                      size: 44,
                      color: Colors.white,
                    ),
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
            style: AppTheme.display(context, size: context.adaptiveFont(26)),
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
            duration: const Duration(milliseconds: 1300),
          ),
        ),
        Center(
          child: Text(
            AppConstants.appTagline,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
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
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.xs,
            // Fixed cell height so a 3×2 strip always fits the content.
            mainAxisExtent: 84,
            children: [
              _StatTile(
                icon: Icons.brush_outlined,
                label: 'Paintings',
                value: paintings,
                format: (v) => v.round().toString(),
              ),
              _StatTile(
                icon: Icons.person_outline,
                label: 'Artists',
                value: artists,
                format: (v) => v.round().toString(),
              ),
              _StatTile(
                icon: Icons.description_outlined,
                label: 'Documents',
                value: documents,
                format: (v) => v.round().toString(),
              ),
              _StatTile(
                icon: Icons.photo_library_outlined,
                label: 'Stored images',
                value: storedImages,
                format: (v) => v.round().toString(),
              ),
              _StatTile(
                icon: Icons.storage_outlined,
                label: 'Vault size',
                value: vaultBytes,
                format: (v) => Formatters.bytes(v.round()),
              ),
              _StatTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Plan',
                value: plan.isPro ? 1 : 0,
                format: (v) => plan.isPro ? 'Pro' : 'Free',
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
                'ArtVault is a professional-grade private digital gallery '
                'built for collectors, curators and galleries. Every artwork '
                'lives on-device first with AES-256 encryption, with optional '
                'cloud sync, smart duplicate detection, QR identification, '
                'provenance tracking, condition reports, role-based access '
                'control, real Pro billing via Google Play, revocable public '
                'gallery links with expiry and analytics, and full catalogue '
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
              _cardTitle(
                context,
                Icons.workspace_premium_outlined,
                'Capabilities',
              ),
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
              _infoRow(
                context,
                'Data model',
                'Offline-first · Supabase + Firebase',
              ),
              _infoRow(context, 'Security', 'AES-256 · PBKDF2 · App Check'),
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
        // SUPPORT — contact & rate the app
        // ------------------------------------------------------------------
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle(context, Icons.support_agent_outlined, 'Support'),
              const SizedBox(height: AppSpacing.xs),
              _link(
                context,
                'Send feedback',
                subtitle:
                    'Questions, suggestions or issues — email the developer',
                icon: Icons.mail_outline,
                onTap: () => _launch(
                  'mailto:${AppConstants.supportEmail}'
                  '?subject=ArtVault%20Feedback',
                ),
              ),
              _link(
                context,
                'Rate ArtVault',
                subtitle: 'Enjoying the app? Leave a review on Google Play',
                icon: Icons.star_border,
                onTap: () => _launch(AppConstants.playStoreUrl),
              ),
              _link(
                context,
                'Share ArtVault',
                subtitle: 'Tell a fellow collector about the app',
                icon: Icons.ios_share,
                onTap: () => ShareService.instance.shareText(
                  'Discover ArtVault — your private digital gallery. Organise, '
                  'analyse and protect your art collection, all on your device. '
                  '${AppConstants.playStoreUrl}',
                  subject: 'ArtVault — your private gallery',
                ),
              ),
            ],
          ),
        ),
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
              _link(
                context,
                'Privacy policy',
                onTap: () =>
                    _launch('https://artvault-d69d0.web.app/privacy.html'),
              ),
              _link(
                context,
                'Terms of service',
                onTap: () =>
                    _launch('https://artvault-d69d0.web.app/terms.html'),
              ),
              _link(
                context,
                'Licences',
                onTap: () =>
                    _launch('https://artvault-d69d0.web.app/licenses.html'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ------------------------------------------------------------------
        // FOOTER — Developer card + tech stack + copyright
        // ------------------------------------------------------------------
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // --- Developer identity ---
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'KH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GradientShimmerText(
                text: 'Kais Havery',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                duration: const Duration(milliseconds: 1400),
              ),
              const SizedBox(height: 2),
              Text(
                'Founder & Lead Developer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Architecting ArtVault — your private digital gallery',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),

              // --- Decorative divider ---
              Container(
                width: 60,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.0),
                      scheme.primary.withValues(alpha: 0.4),
                      scheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- Tech stack badges ---
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _TechBadge(label: 'Flutter', icon: Icons.phone_android),
                  _TechBadge(label: 'Dart', icon: Icons.code),
                  _TechBadge(label: 'Supabase', icon: Icons.storage),
                  _TechBadge(
                    label: 'Firebase',
                    icon: Icons.local_fire_department,
                  ),
                  _TechBadge(label: 'Hive', icon: Icons.cabin),
                  _TechBadge(label: 'Riverpod', icon: Icons.water_drop),
                ],
              ),
              const SizedBox(height: 14),

              // --- Build info ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 13,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'v$appVersion · Build $appBuild · $engineLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- Contact links ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FooterIconButton(
                    icon: Icons.mail_outline,
                    tooltip: 'Email',
                    onTap: () => _launch(
                      'mailto:${AppConstants.supportEmail}'
                      '?subject=ArtVault%20Feedback',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FooterIconButton(
                    icon: Icons.star_border,
                    tooltip: 'Rate on Play Store',
                    onTap: () => _launch(AppConstants.playStoreUrl),
                  ),
                  const SizedBox(width: 12),
                  _FooterIconButton(
                    icon: Icons.ios_share,
                    tooltip: 'Share ArtVault',
                    onTap: () => ShareService.instance.shareText(
                      'Discover ArtVault — your private digital gallery. '
                      '${AppConstants.playStoreUrl}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // --- Copyright ---
              Text(
                '© 2026 Kais Havery. All rights reserved.',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
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
      body: Stack(
        children: [
          // Ambient aurora glow hugging the hero zone at the top of the page
          // (logo, wordmark, tagline, version pill) — same treatment the home
          // screen gives its greeting header. Below it the ambient gradient
          // shows through the glass cards, so the drift follows the hero
          // instead of washing the whole page.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // In landscape, shrink the aurora since there's less vertical space.
            height:
                MediaQuery.sizeOf(context).width >
                    MediaQuery.sizeOf(context).height
                ? 200
                : 340,
            child: const IgnorePointer(child: AuroraBackground()),
          ),
          ListView(padding: AppSpacing.screenPadding, children: children),
          // Museum-style vignette: softly darkens the edges and casts a warm
          // gallery-light glow in the corners, like light falling on art.
          Positioned.fill(
            child: const IgnorePointer(child: FilmVignette(strength: 0.14)),
          ),
        ],
      ),
    );
  }

  static Widget _cardTitle(BuildContext context, IconData icon, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }

  static Widget _featureChip(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        color: scheme.primary.withValues(alpha: 0.06),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
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
                color: scheme.onSurface.withValues(alpha: 0.65),
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

  static Widget _link(
    BuildContext context,
    String label, {
    String? subtitle,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: icon == null
          ? null
          : Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 11.5)),
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

/// A single vault-stat tile in the stats strip: icon + animated count +
/// label. The [format] callback decides how the animated value renders
/// (integers, bytes, or a plan name).
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String Function(double) format;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 6),
        AnimatedCountUp(
          value: value.toDouble(),
          format: format,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Transparency list of every celebration that has fired (Pro unlock,
/// gallery published) with the date it happened. Streams the persisted
/// history so a new celebration appears the moment it fires.
class _CelebrationsCard extends ConsumerWidget {
  const _CelebrationsCard();

  static const _labels = <String, String>{
    'pro-unlock': 'Pro unlocked',
    'gallery-published': 'Gallery published',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Rebuild when the settings box changes (markCelebrated writes there).
    ref.watch(settingsBoxProvider);
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
              const Divider(height: 1, indent: 16, color: Color(0x0D000000)),
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
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small chip showing a technology used in the app.
class _TechBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _TechBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        color: scheme.primary.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button used in the footer contact row.
class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _FooterIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
