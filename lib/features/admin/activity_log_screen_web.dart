import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/widgets/web/skeleton_shimmer.dart';

/// Web-optimized activity log with data table, filters, and CSV export.
class ActivityLogScreenWeb extends ConsumerStatefulWidget {
  const ActivityLogScreenWeb({super.key});

  @override
  ConsumerState<ActivityLogScreenWeb> createState() =>
      _ActivityLogScreenWebState();
}

class _ActivityLogScreenWebState extends ConsumerState<ActivityLogScreenWeb> {
  String _searchQuery = '';
  ActivityType? _filterType;

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(activityAuditProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Activity Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 280,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search activity...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Export CSV
                _ExportButton(onExport: () => _exportCsv(auditAsync)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(activityAuditProvider),
                ),
              ],
            ),
          ),
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _FilterChipWidget(
                  label: 'All',
                  selected: _filterType == null,
                  onTap: () => setState(() => _filterType = null),
                ),
                const SizedBox(width: 8),
                for (final type in ActivityType.values)
                  _FilterChipWidget(
                    label: type.label,
                    icon: type.icon,
                    color: type.color,
                    selected: _filterType == type,
                    onTap: () => setState(() => _filterType = type),
                  ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: auditAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: TableSkeleton(rows: 6, columns: 4),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load activity log',
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(activityAuditProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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
                  filtered = filtered
                      .where((e) => e.type == _filterType)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: scheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No activity found',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Entry count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} of ${entries.length} entries',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    // Table
                    Expanded(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              scheme.surfaceContainerHighest.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Time',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'User',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Action',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Details',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            rows: filtered.map((entry) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMM d, HH:mm',
                                          ).format(entry.at),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          _formatTimeAgo(entry.at),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: entry.type.color
                                              .withValues(alpha: 0.12),
                                          child: Icon(
                                            entry.type.icon,
                                            size: 14,
                                            color: entry.type.color,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.userName.isNotEmpty
                                                  ? entry.userName
                                                  : 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (entry.userEmail.isNotEmpty)
                                              Text(
                                                entry.userEmail,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: scheme.onSurface
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: entry.type.color.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        entry.type.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: entry.type.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 300,
                                      ),
                                      child: Text(
                                        entry.description.isNotEmpty
                                            ? entry.description
                                            : entry.type.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurface.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  void _exportCsv(AsyncValue<List<ActivityAuditEntry>> auditAsync) {
    final entries = auditAsync.valueOrNull ?? [];
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

    final buffer = StringBuffer('Time,User,Email,Action,Details\n');
    for (final e in filtered) {
      buffer.writeln(
        '${DateFormat('yyyy-MM-dd HH:mm').format(e.at)},'
        '${_csvEscape(e.userName)},'
        '${_csvEscape(e.userEmail)},'
        '${_csvEscape(e.type.label)},'
        '${_csvEscape(e.description)}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    }
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _formatTimeAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? c.withValues(alpha: 0.15)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? c.withValues(alpha: 0.4)
                : scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c : scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onExport;
  const _ExportButton({required this.onExport});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onExport,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 14, color: scheme.onSurface),
            const SizedBox(width: 4),
            Text(
              'Export CSV',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
