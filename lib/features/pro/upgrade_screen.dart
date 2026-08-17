import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/pro_limits.dart';
import '../../core/services/play_purchase_verifier.dart';
import '../../core/services/pro_billing_service.dart';
import '../../core/services/razorpay_payment_service.dart';
import '../../core/theme/app_spacing.dart';
import 'pro_celebration.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_user.dart' show AppPlan;

/// In-app upgrade screen. The primary path is a real purchase through the
/// device store ([ProBillingService]); the plan flag is written to Firestore
/// (admin-gated by the rules) and cached locally so the entitlement works
/// offline-first exactly like roles.
///
/// When the store isn't configured yet (debug builds, sideloaded APKs), the
/// screen offers a real Razorpay checkout (UPI / cards / netbanking) when
/// `--dart-define=RAZORPAY_KEY_ID` is set — the payment is verified by a
/// Cloud Function before the plan is granted. Only when no payment path
/// exists at all does a *clearly labelled* developer preview unlock appear
/// behind an explicit confirmation dialog (debug builds only; never in
/// release).
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _busy = false;
  bool _restoring = false;
  ProductDetails? _product;
  bool _storeUnavailable = false;

  /// Razorpay billing mode (one-time unlock vs monthly subscription); only
  /// shown when the Razorpay payment path is active.
  RazorpayBillingMode _billingMode = RazorpayBillingMode.oneTime;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final available = await ProBillingService.instance.isAvailable;
    if (!mounted) return;
    if (!available) {
      setState(() => _storeUnavailable = true);
      return;
    }
    final product = await ProBillingService.instance.getProProduct();
    if (!mounted) return;
    setState(() {
      _product = product;
      _storeUnavailable = product == null;
    });
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null || _busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await ProBillingService.instance.buy(product);
      if (!mounted) return;
      switch (outcome?.result) {
        case ProPurchaseResult.purchased:
          // The Firestore rules only let an admin change a user's plan, so
          // a Play buyer (usually not an admin) must be granted server-side
          // after the Cloud Function validates the purchase token.
          final verified = await PlayPurchaseVerifier.instance.verify(
            productId: product.id,
            purchaseToken: outcome?.purchaseToken ?? '',
          );
          if (verified != ProPurchaseResult.purchased) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Payment received, but it could not be verified yet. '
                    'It will activate once verified.',
                  ),
                ),
              );
            }
            break;
          }
          await ref.read(authProvider.notifier).applyServerPlanGrant(
            AppPlan.pro,
          );
          if (!mounted) return;
          // Celebratory moment before returning to the app.
          await showProCelebration(context);
          if (!mounted) return;
          context.pop();
        case ProPurchaseResult.pending:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waiting for payment confirmation…')),
          );
        case ProPurchaseResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. Please try again.'),
            ),
          );
        case ProPurchaseResult.unavailable:
        case null:
          // Cancelled by the user, or store not configured — silent.
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final ok = await ProBillingService.instance.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Restore started — if you have a purchase it will appear here.'
              : 'Could not reach the store to restore purchases.',
        ),
      ),
    );
  }

  /// Razorpay checkout (UPI / cards / netbanking) for builds where the
  /// store isn't available. The payment is verified by the Cloud Function
  /// backend before the plan is granted. [monthly] chooses the recurring
  /// subscription instead of the one-time unlock.
  Future<void> _buyRazorpay({bool monthly = false}) async {
    final user = ref.read(authProvider).user;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await RazorpayPaymentService.instance.checkout(
        uid: user.uid,
        email: user.email,
        name: user.displayName,
        mode: monthly
            ? RazorpayBillingMode.monthly
            : RazorpayBillingMode.oneTime,
      );
      if (!mounted) return;
      switch (result) {
        case ProPurchaseResult.purchased:
          // The backend wrote the plan with the Admin SDK (verified
          // signature); reflect the grant locally — the live profile
          // watcher reconciles with the server document.
          await ref.read(authProvider.notifier).applyServerPlanGrant(
            AppPlan.pro,
          );
          if (!mounted) return;
          await showProCelebration(context);
          if (!mounted) return;
          context.pop();
        case ProPurchaseResult.pending:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waiting for payment confirmation…')),
          );
        case ProPurchaseResult.error:
        case ProPurchaseResult.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment could not be completed. Please try again.'),
            ),
          );
        case null:
          // Cancelled by the user — silent.
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Developer preview unlock, only reachable through an explicit
  /// confirmation dialog on debug builds. Never grants Pro in release — a
  /// paid entitlement must not be handed out for free in a shipped build.
  Future<void> _confirmPreviewUnlock() async {
    if (kReleaseMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No payment method is configured on this build yet. '
              'Purchases will be available once the app is published.',
            ),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.developer_mode, size: 32),
        title: const Text('Developer preview unlock?'),
        content: const Text(
          'This build has no payment method configured, so this is a free '
          'developer preview — no payment is processed. '
          'Activate Pro for testing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate preview'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authProvider.notifier).updatePlan(AppPlan.pro);
    if (!mounted) return;
    // Same celebration as a real purchase — the entitlement is now live.
    await showProCelebration(context);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
              GradientShimmerText(
                text: 'ArtVault Pro',
                style: AppTheme.display(context, size: 22),
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                duration: const Duration(milliseconds: 1400),
                loop: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _product != null
                    ? '${_product!.price} / month · cancel anytime'
                    : 'Monthly subscription · cancel anytime',
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
              else if (_busy)
                FilledButton.icon(
                  onPressed: null,
                  icon: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: const Text('Processing…'),
                )
              else ...[
                // Payment paths, in priority order: the device store when
                // available, then Razorpay (sideloaded builds), then — only
                // on debug builds, behind a confirmation dialog — the free
                // developer preview unlock.
                if (_storeUnavailable &&
                    RazorpayPaymentService.instance.isConfigured) ...[
                  SegmentedButton<RazorpayBillingMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: RazorpayBillingMode.oneTime,
                        icon: Icon(Icons.bolt, size: 16),
                        label: Text('One-time'),
                      ),
                      ButtonSegment(
                        value: RazorpayBillingMode.monthly,
                        icon: Icon(Icons.repeat, size: 16),
                        label: Text('Monthly'),
                      ),
                    ],
                    selected: {_billingMode},
                    onSelectionChanged: (selection) {
                      setState(() => _billingMode = selection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // The CTA breathes gently so the paid moment feels alive.
                _GlowPulse(
                  color: scheme.primary,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : _storeUnavailable
                        ? (RazorpayPaymentService.instance.isConfigured
                              ? () => _buyRazorpay(
                                    monthly:
                                        _billingMode ==
                                        RazorpayBillingMode.monthly,
                                  )
                              : _confirmPreviewUnlock)
                        : _buy,
                    icon: const Icon(Icons.workspace_premium, size: 18),
                    label: Text(
                      _storeUnavailable
                          ? (RazorpayPaymentService.instance.isConfigured
                                ? _billingMode == RazorpayBillingMode.monthly
                                      ? 'Subscribe monthly — ₹'
                                            '${(RazorpayPaymentService.proMonthlyPricePaise / 100).toStringAsFixed(0)}'
                                      : 'Unlock — ₹'
                                            '${(RazorpayPaymentService.proPricePaise / 100).toStringAsFixed(0)}'
                                : (kReleaseMode
                                      ? 'Unlock Pro'
                                      : 'Unlock Pro (preview)'))
                          : 'Subscribe — ${_product?.price ?? ''}'.trim(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _storeUnavailable
                      ? (RazorpayPaymentService.instance.isConfigured
                            ? 'Payment is processed securely by Razorpay (UPI / '
                                'cards / netbanking) and verified by our server '
                                'before Pro is activated.'
                            : 'No payment method is configured on this build '
                                'yet. ${kReleaseMode ? '' : 'The button is a free developer preview. '}'
                                'Real payments arrive with the store or Razorpay.')
                      : 'Payment is processed securely by your device\'s app store. '
                          'Your plan syncs to the cloud and unlocks on every device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                if (!_storeUnavailable) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: _restoring ? null : _restore,
                    icon: const Icon(Icons.settings_backup_restore, size: 16),
                    label: const Text('Restore purchases'),
                  ),
                ],
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

/// Soft breathing glow behind a primary action. Ticker-only (no timers), so
/// tests that end mid-flight stay clean, and reduced motion renders it
/// statically — same convention as the rest of the app's motion widgets.
class _GlowPulse extends StatefulWidget {
  final Color color;
  final Widget child;

  const _GlowPulse({required this.color, required this.child});

  @override
  State<_GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<_GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the ticker idle under reduced motion so widget tests can settle.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.35 + 0.3 * _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 * pulse),
                blurRadius: 18 + 10 * pulse,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
