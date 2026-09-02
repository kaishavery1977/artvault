// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/widgets/web/skeleton_shimmer.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';

/// Web-optimized admin user management with data table, split panels, and batch actions.
/// Accessible only on web via kIsWeb guards in the router.
class AdminUsersScreenWeb extends ConsumerStatefulWidget {
  const AdminUsersScreenWeb({super.key});

  @override
  ConsumerState<AdminUsersScreenWeb> createState() =>
      _AdminUsersScreenWebState();
}

class _AdminUsersScreenWebState extends ConsumerState<AdminUsersScreenWeb> {
  String _searchQuery = '';
  AppRole? _roleFilter;
  AppUser? _selectedUser;
  final Set<String> _selectedUids = {};
  bool _sortAscending = true;
  int _sortColumnIndex = 1; // name

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final revokedAsync = ref.watch(revokedProvider);
    final me = ref.watch(authProvider.select((a) => a.user));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: usersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: TableSkeleton(rows: 8, columns: 7),
        ),
        error: (e, _) => _buildError(context, e),
        data: (allUsers) {
          var users = _applyFilters(allUsers);
          return Row(
            children: [
              // Main panel: table + actions
              Expanded(
                flex: 3,
                child: _buildTablePanel(context, ref, users, me, scheme),
              ),
              // Detail panel
              if (_selectedUser != null)
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: _buildDetailPanel(context, ref, _selectedUser!, scheme),
                ),
              // Revoked accounts panel
              if (_selectedUser == null)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: _buildRevokedPanel(context, ref, revokedAsync, scheme),
                ),
            ],
          );
        },
      ),
    );
  }

  List<AppUser> _applyFilters(List<AppUser> users) {
    var filtered = users;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    }
    if (_roleFilter != null) {
      filtered = filtered.where((u) => u.role == _roleFilter).toList();
    }
    // Sort
    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // checkbox — skip
          cmp = 0;
        case 1: // name
          cmp = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        case 2: // email
          cmp = a.email.toLowerCase().compareTo(b.email.toLowerCase());
        case 3: // role
          cmp = a.role.index.compareTo(b.role.index);
        case 4: // plan
          cmp = a.plan.index.compareTo(b.plan.index);
        case 5: // joined
          cmp = a.createdAt.compareTo(b.createdAt);
        case 6: // last login
          cmp = a.lastLogin.compareTo(b.lastLogin);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  Widget _buildTablePanel(
    BuildContext context,
    WidgetRef ref,
    List<AppUser> users,
    AppUser? me,
    ColorScheme scheme,
  ) {
    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Text('Users & Roles',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              // Search
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Role filter
              PopupMenuButton<AppRole?>(
                tooltip: 'Filter by role',
                onSelected: (r) => setState(() => _roleFilter = r),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('All roles')),
                  for (final r in AppRole.values)
                    PopupMenuItem(value: r, child: Text(r.label)),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, size: 16, color: scheme.onSurface),
                      const SizedBox(width: 6),
                      Text(_roleFilter?.label ?? 'All',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedUids.isNotEmpty) ...[
                _ActionChip(
                  label: 'Change role (${_selectedUids.length})',
                  icon: Icons.admin_panel_settings,
                  color: scheme.primary,
                  onTap: () => _bulkChangeRole(context, ref),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Revoke (${_selectedUids.length})',
                  icon: Icons.person_remove_outlined,
                  color: scheme.error,
                  onTap: () => _bulkRevoke(context, ref),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  ref.invalidate(usersProvider);
                  ref.invalidate(revokedProvider);
                },
              ),
            ],
          ),
        ),
        // Data table
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 48, color: scheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No users found',
                          style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(scheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                      showCheckboxColumn: true,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columns: [
                        DataColumn(
                          numeric: true,
                          label: _SortHeader(
                            label: '',
                            column: 0,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Name',
                            column: 1,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Email',
                            column: 2,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Role',
                            column: 3,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Plan',
                            column: 4,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Joined',
                            column: 5,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        DataColumn(
                          label: _SortHeader(
                            label: 'Last login',
                            column: 6,
                            currentIndex: _sortColumnIndex,
                            ascending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: users.map((user) {
                        final isSelected = _selectedUids.contains(user.uid);
                        final isMe = me?.uid == user.uid;
                        final isSelectedRow = _selectedUser?.uid == user.uid;
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedUids.add(user.uid);
                              } else {
                                _selectedUids.remove(user.uid);
                              }
                            });
                          },
                          color: WidgetStateProperty.resolveWith((states) {
                            if (isSelectedRow) {
                              return scheme.primary.withValues(alpha: 0.08);
                            }
                            return null;
                          }),
                          cells: [
                            DataCell(
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    _roleColor(user.role, scheme).withValues(alpha: 0.15),
                                child: Icon(
                                  _roleIcon(user.role),
                                  size: 14,
                                  color: _roleColor(user.role, scheme),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(user.displayName,
                                      style: TextStyle(
                                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                                      )),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('You',
                                          style: TextStyle(
                                              fontSize: 10, color: scheme.primary)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(Text(user.email.isEmpty ? '—' : user.email,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurface.withValues(alpha: 0.7)))),
                            DataCell(_RoleChip(role: user.role)),
                            DataCell(
                              user.plan == AppPlan.pro
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('PRO',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.primary)),
                                    )
                                  : Text('Free',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurface.withValues(alpha: 0.5))),
                            ),
                            DataCell(Text(
                                DateFormat('MMM d, yyyy').format(user.createdAt),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                                DateFormat('MMM d, HH:mm').format(user.lastLogin),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Role change
                                  if (!isMe)
                                    PopupMenuButton<AppRole>(
                                      tooltip: 'Change role',
                                      icon: Icon(Icons.swap_horiz,
                                          size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
                                      onSelected: (role) =>
                                          _changeRole(context, ref, user, role),
                                      itemBuilder: (_) => [
                                        for (final r in AppRole.values)
                                          PopupMenuItem(
                                            value: r,
                                            child: Row(
                                              children: [
                                                Icon(_roleIcon(r),
                                                    size: 14, color: _roleColor(r, scheme)),
                                                const SizedBox(width: 8),
                                                Text(r.label),
                                                if (r == user.role) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.check, size: 14),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  // More actions
                                  PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    icon: Icon(Icons.more_horiz,
                                        size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'details':
                                          setState(() => _selectedUser = user);
                                        case 'revoke':
                                          if (!isMe) _revoke(context, ref, user);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: 'details',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.info_outline, size: 18),
                                            title: Text('View details'),
                                          )),
                                      if (!isMe)
                                        PopupMenuItem(
                                            value: 'revoke',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.person_remove_outlined,
                                                  size: 18, color: Color(0xFFEF4444)),
                                              title: const Text('Revoke',
                                                  style: TextStyle(color: Color(0xFFEF4444))),
                                            )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(
      BuildContext context, WidgetRef ref, AppUser user, ColorScheme scheme) {
    return Column(
      children: [
        // Detail header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _roleColor(user.role, scheme).withValues(alpha: 0.15),
                child: Icon(_roleIcon(user.role),
                    size: 24, color: _roleColor(user.role, scheme)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(user.email.isEmpty ? 'No email' : user.email,
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedUser = null),
              ),
            ],
          ),
        ),
        // Detail body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailInfoRow(label: 'Role', value: user.role.label),
                _DetailInfoRow(
                    label: 'Plan',
                    value: '${user.plan.label}${user.plan.isPro ? ' ★' : ''}'),
                _DetailInfoRow(
                    label: 'Joined',
                    value: DateFormat('MMMM d, yyyy').format(user.createdAt)),
                _DetailInfoRow(
                    label: 'Last login',
                    value: DateFormat('MMM d, yyyy HH:mm').format(user.lastLogin)),
                const SizedBox(height: 20),
                // Plan management
                Text('Subscription Plan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: user.plan == AppPlan.free
                            ? null
                            : () async {
                                await AuthRepository.instance
                                    .updatePlan(user.uid, AppPlan.free);
                                ref.invalidate(usersProvider);
                                setState(() => _selectedUser = null);
                              },
                        child: const Text('Free'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: user.plan == AppPlan.pro
                            ? null
                            : () async {
                                await AuthRepository.instance
                                    .updatePlan(user.uid, AppPlan.pro);
                                ref.invalidate(usersProvider);
                                setState(() => _selectedUser = null);
                              },
                        child: const Text('Pro ★'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Actions
                Text('Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontSize: 14)),
                const SizedBox(height: 8),
                if (user.role != AppRole.admin) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _bulkChangeRole(context, ref),
                      icon: const Icon(Icons.admin_panel_settings, size: 18),
                      label: const Text('Change role'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (ref.read(authProvider).user?.uid != user.uid) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                      ),
                      onPressed: () => _revoke(context, ref, user),
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: const Text('Revoke account'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevokedPanel(
      BuildContext context,
      WidgetRef ref,
      AsyncValue<List<RevokedAccount>> revokedAsync,
      ColorScheme scheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.person_remove_outlined,
                  size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Text('Revoked Accounts',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: revokedAsync.when(
            loading: () =>
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CardSkeleton(height: 48),
                ),
            error: (e, _) => Center(
              child: Text('Error loading',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
            ),
            data: (revoked) {
              if (revoked.isEmpty) {
                return Center(
                  child: Text('No revoked accounts',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5))),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: revoked.length,
                itemBuilder: (context, i) {
                  final account = revoked[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(account.displayName.isEmpty
                          ? account.uid
                          : account.displayName),
                      subtitle: Text(account.email,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.5))),
                      trailing: TextButton(
                        onPressed: () => _restore(context, ref, account),
                        child: const Text('Restore'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object e) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 48, color: scheme.error.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Could not load users',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text(e.toString().substring(0, 100.clamp(0, e.toString().length)),
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => ref.invalidate(usersProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  // ---- Actions (same logic as mobile) ----

  Future<void> _changeRole(
      BuildContext context, WidgetRef ref, AppUser user, AppRole role) async {
    if (role == user.role) return;
    final me = ref.read(authProvider).user;
    if (me?.uid == user.uid && role != AppRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot demote your own account.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change role?'),
        content: Text('Set ${user.displayName} to ${role.label}?\n\n${role.description}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthRepository.instance.updateRole(user.uid, role);
      ref.invalidate(usersProvider);
      ref.invalidate(roleAuditProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${user.displayName} is now ${role.label}.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _revoke(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, size: 32),
        title: const Text('Revoke account?'),
        content: Text('Remove ${user.displayName} (${user.email}) from this vault?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthRepository.instance.revokeUser(user.uid,
          email: user.email, displayName: user.displayName);
      ref.invalidate(usersProvider);
      ref.invalidate(revokedProvider);
      setState(() => _selectedUser = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _restore(
      BuildContext context, WidgetRef ref, RevokedAccount account) async {
    final name = account.displayName.isEmpty ? account.uid : account.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore account?'),
        content: Text('Restore $name? They will be able to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthRepository.instance.restoreUser(account.uid);
      ref.invalidate(revokedProvider);
      ref.invalidate(usersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _bulkChangeRole(BuildContext context, WidgetRef ref) async {
    if (_selectedUids.isEmpty) return;
    final users = ref.read(usersProvider).valueOrNull ?? [];
    final selected = users.where((u) => _selectedUids.contains(u.uid)).toList();
    final targetRole = await showDialog<AppRole>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role for ${selected.length} users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in AppRole.values)
              ListTile(
                title: Text(r.label),
                subtitle: Text(r.description, style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (targetRole == null) return;
    var ok = 0;
    for (final u in selected) {
      try {
        await AuthRepository.instance.updateRole(u.uid, targetRole);
        ok++;
      } catch (_) {}
    }
    ref.invalidate(usersProvider);
    ref.invalidate(roleAuditProvider);
    setState(() => _selectedUids.clear());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Updated $ok of ${selected.length} users.')));
    }
  }

  Future<void> _bulkRevoke(BuildContext context, WidgetRef ref) async {
    if (_selectedUids.isEmpty) return;
    final users = ref.read(usersProvider).valueOrNull ?? [];
    final selected = users.where((u) => _selectedUids.contains(u.uid)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, size: 32),
        title: Text('Revoke ${selected.length} users?'),
        content: Text('Remove ${selected.length} account(s) from this vault?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var ok = 0;
    for (final u in selected) {
      try {
        await AuthRepository.instance.revokeUser(u.uid,
            email: u.email, displayName: u.displayName);
        ok++;
      } catch (_) {}
    }
    ref.invalidate(usersProvider);
    ref.invalidate(revokedProvider);
    setState(() => _selectedUids.clear());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Revoked $ok of ${selected.length} users.')));
    }
  }

  Color _roleColor(AppRole role, ColorScheme scheme) {
    switch (role) {
      case AppRole.admin:
        return scheme.primary;
      case AppRole.curator:
        return const Color(0xFFF59E0B);
      case AppRole.viewer:
        return scheme.onSurface;
    }
  }

  IconData _roleIcon(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return Icons.admin_panel_settings;
      case AppRole.curator:
        return Icons.brush_outlined;
      case AppRole.viewer:
        return Icons.visibility_outlined;
    }
  }
}

// ---- Reusable widgets ----

class _RoleChip extends StatelessWidget {
  final AppRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AppRole.admin => scheme.primary,
      AppRole.curator => const Color(0xFFF59E0B),
      AppRole.viewer => scheme.onSurface,
    };
    final icon = switch (role) {
      AppRole.admin => Icons.admin_panel_settings,
      AppRole.curator => Icons.brush_outlined,
      AppRole.viewer => Icons.visibility_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(role.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  final String label;
  final int column;
  final int currentIndex;
  final bool ascending;
  final void Function(int, bool) onSort;

  const _SortHeader({
    required this.label,
    required this.column,
    required this.currentIndex,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == column;
    return GestureDetector(
      onTap: () => onSort(column, isActive ? !ascending : true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: isActive ? 0.9 : 0.6))),
          if (isActive)
            Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
