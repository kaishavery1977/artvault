import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';

/// Live feed of every user action across the vault.
///
/// Streams the Firestore `activity_audit` collection so the admin sees
/// sign-ins, uploads, edits, deletes, role changes, etc. in real time.
/// Filters by user and activity type.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String _searchQuery = '';
  ActivityType? _filterType;

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(activityAuditProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          if (_filterType != null || _searchQuery.isNotEmpty)
            IconButton(
              tooltip: 'Clear filters',
              icon: const Icon(Icons.filter_alt_off, size: 20),
              onPressed: () => setState(() {
                _filterType = null;
                _searchQuery = '';
              }),
            ),
        ],
      ),
      body: auditAsync.when(
        loading: () => const LoadingView(message: 'Loading activity…'),
        error: (e, _) => ErrorState(
          message: 'Could not load activity log.',
          onRetry: () => ref.invalidate(activityAuditProvider),
        ),
        data: (entries) {
          var filtered = entries;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filtered = filtered
                .where(
                  (e) =>
                      e.userName.toLowerCase().contains(q) ||
                      e.userEmail.toLowerCase().contains(q) ||
                      e.description.toLowerCase().contains(q),
                )
                .toList();
          }
          if (_filterType != null) {
            filtered = filtered.where((e) => e.type == _filterType).toList();
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by user or action…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              // Filter chips
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filterType == null,
                      onTap: () => setState(() => _filterType = null),
                    ),
                    for (final type in ActivityType.values)
                      _FilterChip(
                        label: type.label,
                        icon: type.icon,
                        color: type.color,
                        selected: _filterType == type,
                        onTap: () => setState(() => _filterType = type),
                      ),
                  ],
                ),
              ),
              // Entry count
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} entr${filtered.length == 1 ? 'y' : 'ies'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    if (entries.isNotEmpty)
                      Text(
                        'Total: ${entries.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              // Log entries
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.history,
                        title: 'No activity yet',
                        subtitle: _searchQuery.isNotEmpty || _filterType != null
                            ? 'No entries match your filters.'
                            : 'User actions will appear here as they happen.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, i) =>
                            _ActivityEntry(entry: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityEntry extends StatelessWidget {
  final ActivityAuditEntry entry;

  const _ActivityEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeDiff = DateTime.now().difference(entry.at);
    final timeLabel = _formatTime(timeDiff);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity type icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entry.type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.type.icon, size: 18, color: entry.type.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name and type
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.userName.isNotEmpty
                            ? entry.userName
                            : 'Unknown user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TagChip(label: entry.type.label, color: entry.type.color),
                  ],
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '$timeLabel · ${DateFormat('MMM d, HH:mm').format(entry.at)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(Duration diff) {
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? effectiveColor.withValues(alpha: 0.15)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? effectiveColor.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: effectiveColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? effectiveColor
                      : scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
