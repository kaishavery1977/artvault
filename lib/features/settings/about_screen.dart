import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surfaces.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About ArtVault')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.md),
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
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: Text('ArtVault', style: AppTheme.display(context, size: 26))),
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
                  Text(
                    'Built by Kais Havery',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
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
