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

    await AuthRepository.instance.updateRole(user.uid, role);
    ref.invalidate(usersProvider);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('${user.displayName} is now ${role.label}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & roles'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersProvider),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const LoadingView(message: 'Loading users…'),
        error: (e, _) => ErrorState(
          message: 'Could not load users: $e',
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
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
                    onRoleChanged: (role) => _changeRole(context, ref, users[i], role),
                  ),
                  i,
                  key: ValueKey(users[i].uid),
                  context: context,
                ),
                if (i < users.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final ValueChanged<AppRole> onRoleChanged;

  const _UserRow({
    required this.user,
    required this.isMe,
    required this.onRoleChanged,
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
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoleMenu(
            role: user.role,
            onChanged: isMe ? null : onRoleChanged,
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
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
