import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Shows the "limit reached" upgrade dialog. Returns true when the user
/// chooses to upgrade. In that case this helper also pushes `/upgrade`,
/// so callers must not navigate again.
Future<bool> showUpgradePrompt(
  BuildContext context, {
  required String feature,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.secondary],
          ),
        ),
        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
      )
          .animate()
          .scale(
            begin: const Offset(0.7, 0.7),
            duration: 420.ms,
            curve: Curves.easeOutBack,
          ),
      title: const Text('Free plan limit reached'),
      content: Text(
        '$feature is limited on the free plan. Upgrade to ArtVault Pro for '
        'unlimited capacity and premium gallery features.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.workspace_premium, size: 18),
          label: const Text('Upgrade to Pro'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    context.push('/upgrade');
    return true;
  }
  return false;
}
