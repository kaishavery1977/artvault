// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_user.dart';
import '../../data/remote/cloud_backend.dart';
import '../../data/repositories/auth_repository.dart';

/// RBAC user management screen (admin only).
///
/// Lists every registered profile and lets an admin:
///  - Change roles between admin, curator, viewer
///  - Multi-select users for bulk role change or bulk revoke
///  - View detailed user info including storage usage
///  - Force sign-out any user
///  - Revoke / restore accounts
///  - Search and filter users by name or email
///  - Navigate to the full activity audit log
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  bool _selectMode = false;
  final Set<String> _selectedUids = {};

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedUids.clear();
    });
  }

  void _toggleUser(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
        if (_selectedUids.isEmpty) _selectMode = false;
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  void _selectAll(List<AppUser> users) {
    setState(() {
      final allSelected = _selectedUids.length == users.length;
      if (allSelected) {
        _selectedUids.clear();
      } else {
        _selectedUids.addAll(users.map((u) => u.uid));
      }
    });
  }

  // ----------------------------------------------------------- Bulk role --

  Future<void> _bulkChangeRole(BuildContext context, WidgetRef ref) async {
    if (_selectedUids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final users = ref.read(usersProvider).valueOrNull ?? [];
    final selected = users.where((u) => _selectedUids.contains(u.uid)).toList();
    final me = ref.read(authProvider).user;

    // Pick target role
    final targetRole = await showDialog<AppRole>(
      context: context,
      builder: (context) => _BulkRolePicker(currentRoles: selected),
    );
    if (targetRole == null) return;

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings, size: 32),
        title: const Text('Bulk role change?'),
        content: Text(
          'Set ${selected.length} user${selected.length == 1 ? '' : 's'} to '
          '${targetRole.label}?\n\n${targetRole.description}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change roles'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    var succeeded = 0;
    var failed = 0;
    for (final user in selected) {
      if (me?.uid == user.uid && targetRole != AppRole.admin) {
        failed++;
        continue;
      }
      try {
        await AuthRepository.instance.updateRole(user.uid, targetRole);
        succeeded++;
      } catch (_) {
        failed++;
      }
    }

    ref.invalidate(usersProvider);
    ref.invalidate(roleAuditProvider);
    if (context.mounted) {
      setState(() {
        _selectMode = false;
        _selectedUids.clear();
      });
      final msg = failed > 0
          ? 'Updated $succeeded of ${succeeded + failed} users ($failed failed).'
          : 'Updated $succeeded user${succeeded == 1 ? '' : 's'}.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ----------------------------------------------------------- Bulk revoke -

  Future<void> _bulkRevoke(BuildContext context, WidgetRef ref) async {
    if (_selectedUids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final users = ref.read(usersProvider).valueOrNull ?? [];
    final selected = users.where((u) => _selectedUids.contains(u.uid)).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.block, size: 32),
        title: Text(
          'Revoke ${selected.length} user${selected.length == 1 ? '' : 's'}?',
        ),
        content: Text(
          'Remove ${selected.length} account${selected.length == 1 ? '' : 's'} '
          'from this vault?\n\n'
          'Their profiles will be deleted, they will be signed out remotely, '
          'and they cannot sign back in. Vault data stays in the cloud and '
          'can be restored later.',
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
            child: const Text('Revoke all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    var succeeded = 0;
    var failed = 0;
    for (final user in selected) {
      try {
        await AuthRepository.instance.revokeUser(
          user.uid,
          email: user.email,
          displayName: user.displayName,
        );
        succeeded++;
      } catch (_) {
        failed++;
      }
    }

    ref.invalidate(usersProvider);
    ref.invalidate(revokedProvider);
    ref.invalidate(roleAuditProvider);
    if (context.mounted) {
      setState(() {
        _selectMode = false;
        _selectedUids.clear();
      });
      final msg = failed > 0
          ? 'Revoked $succeeded of ${succeeded + failed} users ($failed failed).'
          : 'Revoked $succeeded user${succeeded == 1 ? '' : 's'}.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------------------------------------------------------- Single-user --

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
          'Set ${user.displayName} to ${role.label}?\n\n${role.description}',
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
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final searchQuery = ref.watch(_userSearchQueryProvider);
    final me = ref.watch(authProvider.select((a) => a.user));
    final cloudReady = ref.watch(cloudReadyProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _selectMode
            ? Text('${_selectedUids.length} selected')
            : const Text('Users & roles'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectMode,
              )
            : null,
        actions: [
          if (_selectMode) ...[
            // Select all / deselect all
            IconButton(
              tooltip: 'Select all',
              icon: const Icon(Icons.select_all, size: 22),
              onPressed: () {
                final users = usersAsync.valueOrNull ?? [];
                _selectAll(users);
              },
            ),
            // Bulk role change
            IconButton(
              tooltip: 'Change role',
              icon: const Icon(Icons.admin_panel_settings, size: 22),
              onPressed: _selectedUids.isEmpty
                  ? null
                  : () => _bulkChangeRole(context, ref),
            ),
            // Bulk revoke
            IconButton(
              tooltip: 'Revoke selected',
              icon: Icon(
                Icons.person_remove_outlined,
                size: 22,
                color: scheme.error,
              ),
              onPressed: _selectedUids.isEmpty
                  ? null
                  : () => _bulkRevoke(context, ref),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Center(
                child: TagChip(
                  label: cloudReady ? 'Live' : 'Offline',
                  color: cloudReady
                      ? const Color(0xFF22C55E)
                      : scheme.onSurface,
                ),
              ),
            ),
            // Activity log
            IconButton(
              tooltip: 'Activity log',
              icon: const Icon(Icons.history, size: 22),
              onPressed: () => context.push('/activity-log'),
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
        ],
      ),
      body: usersAsync.when(
        loading: () => const LoadingView(message: 'Loading users…'),
        error: (e, _) => ErrorState(
          message: 'Could not load users: ${_cloudHint(e)}',
          onRetry: () => ref.invalidate(usersProvider),
        ),
        data: (allUsers) {
          // Filter by search query
          var users = allUsers;
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            users = users
                .where(
                  (u) =>
                      u.displayName.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q),
                )
                .toList();
          }

          if (allUsers.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              title: 'No users yet',
              subtitle: 'Profiles appear here once people sign in.',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    if (!cloudReady)
                      GlassCard(
                        padding: AppSpacing.cardPadding,
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_outlined, color: scheme.error),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Cloud not connected — showing your profile only. '
                                'Sign in with cloud sync to see every user live.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
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
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Roles control what each person can do in this vault. '
                              'Admins have full access, curators can edit, viewers are read-only.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Search bar
                    _UserSearchBar(
                      onChanged: (query) {
                        ref.read(_userSearchQueryProvider.notifier).state =
                            query;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // User count + select mode toggle
                    Row(
                      children: [
                        Text(
                          '${users.length} user${users.length == 1 ? '' : 's'}'
                          '${searchQuery.isNotEmpty ? ' (filtered)' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: Icon(
                            _selectMode
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: Text(
                            _selectMode ? 'Done' : 'Select',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _toggleSelectMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (var i = 0; i < users.length; i++) ...[
                      _UserRow(
                        user: users[i],
                        isMe: me?.uid == users[i].uid,
                        isSelected: _selectedUids.contains(users[i].uid),
                        selectMode: _selectMode,
                        onSelect: () => _toggleUser(users[i].uid),
                        onRoleChanged: (role) =>
                            _changeRole(context, ref, users[i], role),
                        onRevoke: () => _revoke(context, ref, users[i]),
                        onShowDetails: () =>
                            _showUserDetails(context, ref, users[i]),
                      ),
                      if (i < users.length - 1)
                        const SizedBox(height: AppSpacing.sm),
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
                ),
              ),
              // Bulk action bar (shown when in select mode with selections)
              if (_selectMode && _selectedUids.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _bulkChangeRole(context, ref),
                            icon: const Icon(
                              Icons.admin_panel_settings,
                              size: 18,
                            ),
                            label: const Text('Change role'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                            ),
                            onPressed: () => _bulkRevoke(context, ref),
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              size: 18,
                            ),
                            label: const Text('Revoke'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------- User details ---

  Future<void> _showUserDetails(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final scheme = Theme.of(context).colorScheme;

    // Fetch storage usage for this user from cloud
    Map<String, dynamic>? userStorage;
    try {
      userStorage = await CloudBackend.instance.fetchDoc(
        'user_storage',
        user.uid,
        pk: 'uid',
      );
    } catch (_) {}

    // Fetch recent activity for this user
    List<ActivityAuditEntry> recentActivity = [];
    try {
      final allActivity = ref.read(activityAuditProvider).valueOrNull ?? [];
      recentActivity = allActivity
          .where((e) => e.uid == user.uid)
          .take(10)
          .toList();
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          switch (user.role) {
            AppRole.admin => Icons.admin_panel_settings,
            AppRole.curator => Icons.brush_outlined,
            AppRole.viewer => Icons.visibility_outlined,
          },
          size: 32,
          color: switch (user.role) {
            AppRole.admin => scheme.primary,
            AppRole.curator => const Color(0xFFF59E0B),
            AppRole.viewer => scheme.onSurface,
          },
        ),
        title: Text(user.displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic info
              _DetailRow('Email', user.email.isEmpty ? 'No email' : user.email),
              _DetailRow('Role', user.role.label),
              _DetailRow(
                'Plan',
                '${user.plan.label}${user.plan.isPro ? ' ★' : ''}',
              ),
              _DetailRow(
                'Joined',
                '${user.createdAt.month}/${user.createdAt.day}/${user.createdAt.year}',
              ),
              _DetailRow(
                'Last login',
                '${user.lastLogin.month}/${user.lastLogin.day}/${user.lastLogin.year}',
              ),
              const SizedBox(height: AppSpacing.md),

              // Storage usage
              Text(
                'Storage Usage',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _StorageBar(
                usedBytes: userStorage?['storageBytes'] as int? ?? 0,
                imagesCount: userStorage?['imagesCount'] as int? ?? 0,
                documentsCount: userStorage?['documentsCount'] as int? ?? 0,
              ),
              const SizedBox(height: AppSpacing.md),

              // Plan management
              Text(
                'Subscription Plan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: user.plan == AppPlan.free
                          ? null
                          : () async {
                              await AuthRepository.instance.updatePlan(
                                user.uid,
                                AppPlan.free,
                              );
                              ref.invalidate(usersProvider);
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: const Text('Free'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: user.plan == AppPlan.pro
                          ? null
                          : () async {
                              await AuthRepository.instance.updatePlan(
                                user.uid,
                                AppPlan.pro,
                              );
                              ref.invalidate(usersProvider);
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: const Text('Pro ★'),
                    ),
                  ),
                ],
              ),

              // Recent activity
              if (recentActivity.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final entry in recentActivity.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          entry.type.icon,
                          size: 14,
                          color: entry.type.color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.description.isNotEmpty
                                ? entry.description
                                : entry.type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          _formatAgo(entry.at),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _formatAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ---------------------------------------------------------------- Providers -

final _userSearchQueryProvider = StateProvider<String>((ref) => '');

// ---------------------------------------------------------------- Widgets --

class _UserSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _UserSearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search users by name or email…',
        prefixIcon: const Icon(Icons.search, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback onSelect;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onRevoke;
  final VoidCallback onShowDetails;

  const _UserRow({
    required this.user,
    required this.isMe,
    required this.isSelected,
    required this.selectMode,
    required this.onSelect,
    required this.onRoleChanged,
    required this.onRevoke,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Select checkbox (in select mode)
          if (selectMode) ...[
            GestureDetector(
              onTap: onSelect,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Avatar(
            name: user.displayName,
            imagePath: user.photoPath,
            imageUrl: user.photoUrl,
            radius: selectMode ? 20 : 24,
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
                    if (user.plan == AppPlan.pro) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
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
          if (!selectMode) ...[
            const SizedBox(width: AppSpacing.sm),
            _RoleMenu(role: user.role, onChanged: isMe ? null : onRoleChanged),
            const SizedBox(width: AppSpacing.xxs),
            // Single actions menu — prevents overflow
            PopupMenuButton<String>(
              tooltip: 'Actions',
              iconSize: 20,
              color: scheme.surface,
              onSelected: (action) {
                switch (action) {
                  case 'details':
                    onShowDetails();
                  case 'revoke':
                    onRevoke();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline, size: 20),
                    title: Text('View details'),
                  ),
                ),
                if (!isMe)
                  const PopupMenuItem(
                    value: 'revoke',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.person_remove_outlined,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                      title: Text(
                        'Revoke account',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
              ],
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

/// Dialog to pick a target role for bulk role change.
class _BulkRolePicker extends StatelessWidget {
  final List<AppUser> currentRoles;

  const _BulkRolePicker({required this.currentRoles});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Count how many users are currently in each role
    final roleCounts = <AppRole, int>{};
    for (final user in currentRoles) {
      roleCounts[user.role] = (roleCounts[user.role] ?? 0) + 1;
    }

    return AlertDialog(
      icon: const Icon(Icons.admin_panel_settings, size: 32),
      title: const Text('Choose target role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${currentRoles.length} user${currentRoles.length == 1 ? '' : 's'} selected',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final role in AppRole.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  switch (role) {
                    AppRole.admin => Icons.admin_panel_settings,
                    AppRole.curator => Icons.brush_outlined,
                    AppRole.viewer => Icons.visibility_outlined,
                  },
                  color: switch (role) {
                    AppRole.admin => scheme.primary,
                    AppRole.curator => const Color(0xFFF59E0B),
                    AppRole.viewer => scheme.onSurface,
                  },
                ),
                title: Text(role.label),
                subtitle: Text(
                  role.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: roleCounts[role] != null
                    ? Text(
                        '${roleCounts[role]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(context, role),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Role history -

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

// ------------------------------------------------------- Revoked accounts --

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

// ------------------------------------------------------ Storage bar widget --

class _StorageBar extends StatelessWidget {
  final int usedBytes;
  final int imagesCount;
  final int documentsCount;

  const _StorageBar({
    required this.usedBytes,
    required this.imagesCount,
    required this.documentsCount,
  });

  static String _bytes(int b) {
    if (b == 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StorageStat(label: 'Total', value: _bytes(usedBytes)),
            const SizedBox(width: AppSpacing.md),
            _StorageStat(label: 'Images', value: '$imagesCount'),
            const SizedBox(width: AppSpacing.md),
            _StorageStat(label: 'Docs', value: '$documentsCount'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (usedBytes / (500 * 1024 * 1024)).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

class _StorageStat extends StatelessWidget {
  final String label;
  final String value;

  const _StorageStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ Detail row widget --

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
