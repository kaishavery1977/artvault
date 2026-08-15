import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/pro_limits.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_user.dart' show AppPlan;

/// In-app upgrade screen. Flipping to Pro is a soft unlock for now — the
/// plan flag is written to Firestore (admin-gated by the rules) and cached
/// locally, so the entitlement works offline-first exactly like roles. A
/// real payment flow (IAP / Stripe) can be bolted on behind the same flag.
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPro = ref.watch(authProvider.select((a) => a.isPro));

    final features = <(IconData, String, String)>[
      (
        Icons.all_inclusive,
        'Unlimited capacity',
        'No caps on paintings, artists or documents — keep your whole '
            'collection in one place.',
      ),
      (
        Icons.storage_outlined,
        'Full-resolution originals',
        'Store originals beyond the ${_mb(ProLimits.freeStorageBytes)} free '
            'tier without compressing your master files.',
      ),
      (
        Icons.insights_outlined,
        'Gallery analytics',
        'See how many times your public gallery link was viewed.',
      ),
      (
        Icons.branding_watermark_outlined,
        'Watermarking',
        'Stamp your name across shared gallery pages so your art stays yours.',
      ),
      (
        Icons.timer_outlined,
        'Longer link expiry',
        'Publish gallery links that stay live for up to a year.',
      ),
      (
        Icons.workspace_premium_outlined,
        'Version history',
        'Before/after restoration photos and per-item change history.',
      ),
    ];

    final rows = staggerReveal(
      [
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(f.$1, color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f.$3,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            children: [
              Text(
                'ArtVault Pro',
                style: AppTheme.display(context, size: 22),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '₹199 / month · cancel anytime',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (isPro)
                FilledButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('You are Pro'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(authProvider.notifier)
                        .updatePlan(AppPlan.pro);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Welcome to ArtVault Pro — unlimited capacity unlocked.',
                          ),
                        ),
                      );
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: const Text('Unlock Pro'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your plan is stored on this device and synced to the cloud. '
                  'A real payment flow is coming soon — this is the preview unlock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      initialDelay: const Duration(milliseconds: 60),
      interval: const Duration(milliseconds: 70),
      context: context,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text('Why go Pro?', style: AppTheme.display(context, size: 24)),
          const SizedBox(height: AppSpacing.md),
          ...rows,
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static String _mb(int? bytes) => bytes == null
      ? 'unlimited'
      : '${(bytes ~/ (1024 * 1024))} MB';
}
