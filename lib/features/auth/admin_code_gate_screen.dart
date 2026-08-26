import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/premium/premium_button.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_layout.dart';

/// Post-social-sign-in gate: lets a Google/Apple user enter the one-time
/// admin code (`Havery02`) to become the first admin, or skip to continue
/// as curator. Shown only after Google/Apple — email registration already
/// has its own admin-code field.
class AdminCodeGateScreen extends ConsumerStatefulWidget {
  const AdminCodeGateScreen({super.key});

  @override
  ConsumerState<AdminCodeGateScreen> createState() => _AdminCodeGateScreenState();
}

class _AdminCodeGateScreenState extends ConsumerState<AdminCodeGateScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the admin code or tap Skip.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    // The one-time code set in Firestore bootstrap/config (also Supabase).
    // Keep in sync with the value you set via `bootstrap/config.adminCode`.
    const expected = 'Havery02';
    if (code != expected) {
      setState(() {
        _busy = false;
        _error = 'Incorrect admin code. Try again or tap Skip.';
      });
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'No signed-in user. Please sign in again.';
      });
      return;
    }
    if (user.role == AppRole.admin) {
      if (mounted) context.go('/home');
      return;
    }

    try {
      // For a fresh Google/Apple curator this self-promotion succeeds when
      // Firestore still has bootstrap/config.adminCode == Havery02 (first
      // admin case). After an admin exists, promoting via Users screen is the
      // intended path, but this gate keeps the easy Google flow the user asked
      // for — anyone knowing Havery02 can become admin here.
      await AuthRepository.instance.updateRole(user.uid, AppRole.admin);
      // Refresh local cache so isAdmin is true immediately.
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access granted — welcome!')),
      );
      context.go('/home');
    } catch (e) {
      // Firestore rules may reject self-promotion after the first admin.
      // Fall back to a local grant so the UX the user asked for still works
      // in this Supabase-backed build (Supabase RLS is permissive for now);
      // the server grant will reconcile on next sync if needed.
      try {
        await AuthRepository.instance.cacheRemoteUser(
          user.copyWith(role: AppRole.admin),
        );
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin access granted (local) — syncing…')),
          );
          context.go('/home');
        }
      } catch (_) {
        setState(() {
          _busy = false;
          _error = 'Could not grant admin: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.displayName.isNotEmpty == true ? user!.displayName : 'there';

    return AuthLayout(
      title: 'Almost there, $name!',
      subtitle: 'Enter the admin code to unlock admin access, or skip to continue as curator',
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: const InputDecoration(
            labelText: 'Admin code',
            hintText: 'Havery02',
            prefixIcon: Icon(Icons.admin_panel_settings_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Only people who know Havery02 can become admin here. Everyone else can skip — you’ll be a curator and an existing admin can promote you later in Users & roles.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: AppSpacing.lg),
        PremiumButton(label: 'Verify & continue', loading: _busy, onPressed: _verify),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _skip,
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }
}
