import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/web/page_fade_in.dart';
import '../../data/models/app_user.dart';

/// Admin-only dashboard home screen for the web app.
/// Shows live vault stats, user overview, recent activity, and quick actions.
/// Only accessible to users who have passed the admin code gate.
class AdminDashboardWeb extends ConsumerWidget {
  const AdminDashboardWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(vaultStatsProvider);
    final usersAsync = ref.watch(usersProvider);
    final activityAsync = ref.watch(activityAuditProvider);
    final revokedAsync = ref.watch(revokedProvider);
    final cloudReady = ref.watch(cloudReadyProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF08090F)
          : const Color(0xFFF8F8FC),
      body: PageFadeIn(
        duration: const Duration(milliseconds: 500),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _DashboardHeader(cloudReady: cloudReady),
            const SizedBox(height: 24),

            // Live stats row
            _StatsRow(stats: stats, scheme: scheme),
            const SizedBox(height: 24),

            // Two-column layout: User overview + Recent activity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: User management overview
                Expanded(
                  flex: 3,
                  child: _UserOverviewCard(
                    usersAsync: usersAsync,
                    revokedAsync: revokedAsync,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 20),
                // Right: Recent activity feed
                Expanded(
                  flex: 2,
                  child: _RecentActivityCard(
                    activityAsync: activityAsync,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick actions
            _QuickActionsGrid(scheme: scheme),
          ],
        ),
      ),
    ),
    );
  }
}

// ---- Dashboard Header ----

class _DashboardHeader extends StatelessWidget {
  final bool cloudReady;
  const _DashboardHeader({required this.cloudReady});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.admin_panel_settings, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage your vault — users, content, and settings',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const Spacer(),
        // Live/Offline badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cloudReady
                ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                : scheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cloudReady
                  ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                  : scheme.error.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cloudReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 14,
                color: cloudReady ? const Color(0xFF22C55E) : scheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                cloudReady ? 'Live' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cloudReady ? const Color(0xFF22C55E) : scheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Stats Row ----

class _StatsRow extends StatelessWidget {
  final VaultStats stats;
  final ColorScheme scheme;
  const _StatsRow({required this.stats, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Paintings',
          value: '${stats.paintings}',
          icon: Icons.palette_outlined,
          color: const Color(0xFF8B5CF6),
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _StatCard(
          label: 'Artists',
          value: '${stats.artists}',
          icon: Icons.person_outlined,
          color: const Color(0xFF22D3EE),
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _StatCard(
          label: 'Documents',
          value: '${stats.documents}',
          icon: Icons.description_outlined,
          color: const Color(0xFFFBBF24),
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _StatCard(
          label: 'Favorites',
          value: '${stats.favorites}',
          icon: Icons.favorite_outline,
          color: const Color(0xFFFB7185),
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _StatCard(
          label: 'Value',
          value: stats.collectionValue > 0
              ? NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(stats.collectionValue)
              : '\$0',
          icon: Icons.trending_up,
          color: const Color(0xFF22C55E),
          scheme: scheme,
        ),
      ],
    );
  }
}

class _StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme scheme;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.scheme,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.06)
                : widget.scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.2)
                  : widget.scheme.outlineVariant.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 16, color: widget.color),
                  ),
                  const Spacer(),
                  AnimatedScale(
                    scale: _hovered ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_outward,
                      size: 14,
                      color: widget.scheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedCountUp(
                value: double.tryParse(widget.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
                format: (v) => widget.value.contains('.') ? v.toStringAsFixed(0) : v.toInt().toString(),
                duration: const Duration(milliseconds: 1200),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: widget.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- User Overview Card ----

class _UserOverviewCard extends ConsumerWidget {
  final AsyncValue<List<AppUser>> usersAsync;
  final AsyncValue<List<RevokedAccount>> revokedAsync;
  final ColorScheme scheme;

  const _UserOverviewCard({
    required this.usersAsync,
    required this.revokedAsync,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = usersAsync.valueOrNull ?? [];
    final revoked = revokedAsync.valueOrNull ?? [];

    // Role breakdown
    final admins = users.where((u) => u.role == AppRole.admin).length;
    final curators = users.where((u) => u.role == AppRole.curator).length;
    final viewers = users.where((u) => u.role == AppRole.viewer).length;
    final proUsers = users.where((u) => u.plan == AppPlan.pro).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Users Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/users'),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User count
          Row(
            children: [
              _MiniStat(
                  label: 'Total',
                  value: '${users.length}',
                  color: scheme.onSurface),
              const SizedBox(width: 16),
              _MiniStat(
                  label: 'Admins',
                  value: '$admins',
                  color: scheme.primary),
              const SizedBox(width: 16),
              _MiniStat(
                  label: 'Curators',
                  value: '$curators',
                  color: const Color(0xFFF59E0B)),
              const SizedBox(width: 16),
              _MiniStat(
                  label: 'Viewers',
                  value: '$viewers',
                  color: scheme.onSurface.withValues(alpha: 0.6)),
            ],
          ),
          const SizedBox(height: 16),
          // Role bar chart
          _RoleBar(
            admins: admins,
            curators: curators,
            viewers: viewers,
            total: users.isEmpty ? 1 : users.length,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          // Pro + Revoked
          Row(
            children: [
              _Pill(
                label: 'Pro: $proUsers',
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              _Pill(
                label: 'Revoked: ${revoked.length}',
                color: scheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Last active users
          if (users.isNotEmpty) ...[
            Text(
              'Recently Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            for (final user in users.take(5))
              _UserMiniRow(user: user, scheme: scheme),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
      ],
    );
  }
}

class _RoleBar extends StatelessWidget {
  final int admins, curators, viewers, total;
  final ColorScheme scheme;
  const _RoleBar({
    required this.admins,
    required this.curators,
    required this.viewers,
    required this.total,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (admins > 0)
                  Expanded(
                    flex: admins,
                    child: Container(color: scheme.primary),
                  ),
                if (curators > 0)
                  Expanded(
                    flex: curators,
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                if (viewers > 0)
                  Expanded(
                    flex: viewers,
                    child: Container(color: scheme.onSurface.withValues(alpha: 0.3)),
                  ),
                if (total - admins - curators - viewers > 0)
                  Expanded(
                    flex: total - admins - curators - viewers,
                    child: Container(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _UserMiniRow extends StatelessWidget {
  final AppUser user;
  final ColorScheme scheme;
  const _UserMiniRow({required this.user, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final color = switch (user.role) {
      AppRole.admin => scheme.primary,
      AppRole.curator => const Color(0xFFF59E0B),
      AppRole.viewer => scheme.onSurface,
    };
    final icon = switch (user.role) {
      AppRole.admin => Icons.admin_panel_settings,
      AppRole.curator => Icons.brush_outlined,
      AppRole.viewer => Icons.visibility_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            user.role.label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Recent Activity Card ----

class _RecentActivityCard extends ConsumerWidget {
  final AsyncValue<List<ActivityAuditEntry>> activityAsync;
  final ColorScheme scheme;
  const _RecentActivityCard({required this.activityAsync, required this.scheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = activityAsync.valueOrNull ?? [];
    final recent = entries.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: const Color(0xFF22D3EE)),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/activity-log'),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No activity yet',
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            )
          else
            for (final entry in recent)
              _ActivityMiniRow(entry: entry, scheme: scheme),
        ],
      ),
    );
  }
}

class _ActivityMiniRow extends StatelessWidget {
  final ActivityAuditEntry entry;
  final ColorScheme scheme;
  const _ActivityMiniRow({required this.entry, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: entry.type.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(entry.type.icon, size: 14, color: entry.type.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName.isNotEmpty ? entry.userName : 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (entry.description.isNotEmpty)
                  Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatTime(entry.at),
            style: TextStyle(
                fontSize: 10,
                color: scheme.onSurface.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ---- Quick Actions Grid ----

class _QuickActionsGrid extends StatelessWidget {
  final ColorScheme scheme;
  const _QuickActionsGrid({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.admin_panel_settings,
              label: 'Manage Users',
              subtitle: 'Roles, revoke, restore',
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push('/users'),
              scheme: scheme,
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.history,
              label: 'Activity Log',
              subtitle: 'All user actions',
              color: const Color(0xFF22D3EE),
              onTap: () => context.push('/activity-log'),
              scheme: scheme,
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.backup_outlined,
              label: 'Backup & Restore',
              subtitle: 'Cloud data management',
              color: const Color(0xFF22C55E),
              onTap: () => context.push('/backup'),
              scheme: scheme,
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.settings_outlined,
              label: 'Settings',
              subtitle: 'Appearance, security',
              color: const Color(0xFF6EE7B7),
              onTap: () => context.push('/settings'),
              scheme: scheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TiltCard(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
