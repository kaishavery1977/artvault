import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows the "limit reached" upgrade dialog. Returns true when the user
/// decides to upgrade (caller can navigate to the upgrade screen itself —
/// this helper just pops with the choice).
Future<bool> showUpgradePrompt(
  BuildContext context, {
  required String feature,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
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
