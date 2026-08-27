import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';

/// RBAC user management screen (admin only).
///
/// Lists every registered profile and lets an admin change roles between
/// [AppRole.admin], [AppRole.curator] and [AppRole.viewer]. The signed-in
/// profile is protected from self-demotion to keep the organisation safe.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.block, size: 32),
        title: const Text('Revoke account?'),
        content: Text(
          'Remove ${user.displayName} (${user.email.isEmpty ? 'no email' : user.email}) '
          'from this vault?\n\n'
          'Their profile is deleted, they are signed out remotely, and they '
          'cannot sign back in. Any vault data they own stays in the cloud '
          'and can be restored by an admin later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthRepository.instance.revokeUser(
        user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not revoke account: ${_cleanError(e)}'),
          ),
        );
      }
      return;
    }
    ref.invalidate(usersProvider);
    ref.invalidate(revokedProvider);
    ref.invalidate(roleAuditProvider);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.displayName} was revoked and signed out.'),
        ),
      );
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    RevokedAccount account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = account.displayName.isEmpty
        ? account.uid
        : account.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_1, size: 32),
        title: const Text('Restore account?'),
        content: Text(
          'Bring $name back?\n\n'
          'They will be able to sign in again as a curator, and their vault '
          'data (which was never deleted) will sync back automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthRepository.instance.restoreUser(account.uid);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not restore account: ${_cleanError(e)}'),
          ),
        );
      }
      return;
    }
    ref.invalidate(revokedProvider);
    ref.invalidate(usersProvider);
    ref.invalidate(roleAuditProvider);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('$name can sign in again.')),
      );
    }
  }

  Future<void> _restoreAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final revoked = ref.read(revokedProvider).valueOrNull ?? const [];
    if (revoked.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_1, size: 32),
        title: const Text('Restore all revoked accounts?'),
        content: Text(
          'Bring back all ${revoked.length} revoked account(s)?\n\n'
          'Each will be able to sign in again as a curator, and their vault '
          'data (which was never deleted) will sync back automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await AuthRepository.instance.restoreAllUsers();
      ref.invalidate(revokedProvider);
      ref.invalidate(usersProvider);
      ref.invalidate(roleAuditProvider);
      if (context.mounted) {
        final msg = result.failed > 0
            ? 'Restored ${result.restored} of '
                  '${result.restored + result.failed} accounts '
                  '(${result.failed} failed).'
            : 'Restored ${result.restored} '
                  'account${result.restored == 1 ? '' : 's'}.';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not restore accounts: ${_cleanError(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    AppRole role,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (role == user.role) return;

    final current = ref.read(authProvider).user;
    if (current != null && current.uid == user.uid && role != AppRole.admin) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You cannot demote your own account.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings, size: 32),
        title: const Text('Change role?'),
        content: Text(
          'Set ${user.displayName} to ${role.label}?\n\n'
          '${role.description}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthRepository.instance.updateRole(user.uid, role);
    } catch (e) {
      // e.g. the rules rejected the write (own role not admin in Firestore)
      // or the network failed — surface the real reason instead of leaving
      // the admin thinking the change went through.
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not update role: ${_cleanError(e)}')),
        );
      }
      return;
    }
    ref.invalidate(usersProvider);
    ref.invalidate(roleAuditProvider);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('${user.displayName} is now ${role.label}.')),
      );
    }
  }

  /// Appends an actionable hint to cloud load failures: a missing App Check
  /// debug token (debug builds must be registered in the console) and a
  /// network drop are the two usual causes of "users won't load".
  static String _cloudHint(Object e) {
    final msg = e.toString();
    if (msg.contains('permission-denied') ||
        msg.contains('Missing or insufficient permissions')) {
      return 'permission denied. If you are running a debug build, make sure '
          'the App Check debug token for this device is registered in the '
          'Firebase console (App Check → Manage debug tokens).';
    }
    if (msg.contains('unavailable') || msg.contains('network')) {
      return 'network error — check your connection and tap retry.';
    }
    return msg.replaceFirst('Exception: ', '').trim().isEmpty
        ? 'something went wrong'
        : msg.replaceFirst('Exception: ', '');
  }

  /// Turns a Firebase permission/network error into a short readable line.
  static String _cleanError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('permission-denied') ||
        msg.contains('Missing or insufficient permissions')) {
      return 'denied by security rules — your account may not be admin yet.';
    }
    if (msg.contains('unavailable') || msg.contains('network')) {
      return 'network error — check your connection and try again.';
    }
    final trimmed = msg.trim();
    return trimmed.isEmpty ? 'something went wrong' : trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(authProvider).user;
    final cloudReady = ref.watch(cloudReadyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & roles'),
        actions: [
          // Live/offline chip: shows whether this list is streaming from
          // the cloud (everyone) or showing only the signed-in profile
          // (cloud not connected).
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Center(
              child: TagChip(
                label: cloudReady ? 'Live' : 'Offline',
                color: cloudReady
                    ? const Color(0xFF22C55E)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(usersProvider);
              ref.invalidate(roleAuditProvider);
            },
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const LoadingView(message: 'Loading users…'),
        error: (e, _) => ErrorState(
          message: 'Could not load users: ${_cloudHint(e)}',
          onRetry: () => ref.invalidate(usersProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              title: 'No users yet',
              subtitle: 'Profiles appear here once people sign in.',
            );
          }
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // When the cloud isn't connected the provider yields only the
              // signed-in profile — say so instead of pretending the list
              // is complete.
              if (!cloudReady)
                GlassCard(
                  padding: AppSpacing.cardPadding,
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Cloud not connected — showing your profile only. '
                          'Sign in with cloud sync to see every user live.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              if (!cloudReady) const SizedBox(height: AppSpacing.md),
              GlassCard(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Roles control what each person can do in this vault. '
                        'Admins have full access, curators can edit, viewers are read-only.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < users.length; i++) ...[
                revealListItem(
                  _UserRow(
                    user: users[i],
                    isMe: me?.uid == users[i].uid,
                    onRoleChanged: (role) =>
                        _changeRole(context, ref, users[i], role),
                    onRevoke: () => _revoke(context, ref, users[i]),
                  ),
                  i,
                  key: ValueKey(users[i].uid),
                  context: context,
                ),
                if (i < users.length - 1) const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),
              _RevokedCard(
                onRestore: (account) => _restore(context, ref, account),
                onRestoreAll: () => _restoreAll(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _RoleHistoryCard(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

/// Recent role-change activity, newest first. Streams `role_audit` live so
/// the admin sees every change (who, whom, old → new, when) as it happens.
class _RoleHistoryCard extends ConsumerWidget {
  const _RoleHistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(roleAuditProvider);
    final audit = auditAsync.valueOrNull ?? const [];
    final shown = audit.take(20).toList();
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Role history',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                shown.length < audit.length
                    ? 'latest ${shown.length} of ${audit.length}'
                    : '${audit.length} change${audit.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (auditAsync.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Could not load role history. Pull refresh to retry.',
                style: TextStyle(fontSize: 12.5, color: scheme.error),
              ),
            )
          else if (audit.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'No role changes recorded yet. Changes you make above will appear here.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            )
          else
            for (final entry in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 15,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_cap(entry.oldRole)} → ${_cap(entry.newRole)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.byEmail.isEmpty ? 'Someone' : entry.byEmail} '
                            '· ${_when(entry.at)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? 'unknown' : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _when(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Revoked accounts with a one-tap restore, so an admin can bring someone
/// back without touching the console.
class _RevokedCard extends ConsumerWidget {
  final ValueChanged<RevokedAccount> onRestore;
  final VoidCallback onRestoreAll;

  const _RevokedCard({required this.onRestore, required this.onRestoreAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revoked = ref.watch(revokedProvider).valueOrNull ?? const [];
    final scheme = Theme.of(context).colorScheme;

    if (revoked.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_off_outlined, size: 20, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Revoked accounts',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${revoked.length}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              if (revoked.length > 1) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  onPressed: onRestoreAll,
                  icon: const Icon(Icons.person_add_alt_1, size: 15),
                  label: const Text('Restore all'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final account in revoked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName.isEmpty
                              ? 'Revoked user'
                              : account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.email.isEmpty
                              ? 'No email on file'
                              : account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: scheme.primary,
                    ),
                    onPressed: () => onRestore(account),
                    icon: const Icon(Icons.person_add_alt_1, size: 15),
                    label: const Text('Restore'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onRevoke;

  const _UserRow({
    required this.user,
    required this.isMe,
    required this.onRoleChanged,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Avatar(
            name: user.displayName,
            imagePath: user.photoPath,
            imageUrl: user.photoUrl,
            radius: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: AppSpacing.xs),
                      TagChip(label: 'You', color: scheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email.isEmpty ? 'No email on file' : user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoleMenu(role: user.role, onChanged: isMe ? null : onRoleChanged),
          if (!isMe) ...[
            const SizedBox(width: AppSpacing.xxs),
            IconButton(
              tooltip: 'Revoke account',
              iconSize: 18,
              color: scheme.error,
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: onRevoke,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  final AppRole role;
  final ValueChanged<AppRole>? onChanged;

  const _RoleMenu({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AppRole.admin => scheme.primary,
      AppRole.curator => const Color(0xFFF59E0B),
      AppRole.viewer => scheme.onSurface,
    };

    return PopupMenuButton<AppRole>(
      tooltip: 'Role',
      enabled: onChanged != null,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final r in AppRole.values)
          PopupMenuItem(
            value: r,
            child: Row(
              children: [
                Icon(
                  switch (r) {
                    AppRole.admin => Icons.admin_panel_settings,
                    AppRole.curator => Icons.brush_outlined,
                    AppRole.viewer => Icons.visibility_outlined,
                  },
                  size: 18,
                  color: switch (r) {
                    AppRole.admin => scheme.primary,
                    AppRole.curator => const Color(0xFFF59E0B),
                    AppRole.viewer => scheme.onSurface,
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(r.label),
                if (r == role) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (role) {
                AppRole.admin => Icons.admin_panel_settings,
                AppRole.curator => Icons.brush_outlined,
                AppRole.viewer => Icons.visibility_outlined,
              },
              size: 15,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              role.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (onChanged != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.arrow_drop_down, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
