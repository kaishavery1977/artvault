import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/states.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.valueOrNull?.any((n) => !n.read) ?? false)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: () => NotificationRepository.instance.markAllRead(),
            ),
          if ((notifications.valueOrNull ?? []).isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => NotificationRepository.instance.clearAll(),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(message: '$e'),
        data: (items) {
          final scheme = Theme.of(context).colorScheme;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              subtitle:
                  'Uploads, backups and duplicate alerts will appear here.',
            );
          }
          final sorted = [...items]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Group by date
          final groups = <String, List<AppNotification>>{};
          final now = DateTime.now();
          for (final n in sorted) {
            final diff = now.difference(n.createdAt);
            final key = diff.inDays == 0
                ? 'Today'
                : diff.inDays == 1
                ? 'Yesterday'
                : diff.inDays < 7
                ? 'This week'
                : 'Older';
            groups.putIfAbsent(key, () => []).add(n);
          }
          final orderedKeys = ['Today', 'Yesterday', 'This week', 'Older']
              .where(groups.containsKey)
              .toList();
          return ListView.builder(
            padding: AppSpacing.screenPadding,
            itemCount: orderedKeys.length,
            itemBuilder: (context, sectionIndex) {
              final key = orderedKeys[sectionIndex];
              final group = groups[key]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                    child: Text(
                      key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  for (final n in group)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: scheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.delete_outline, color: scheme.error),
                        ),
                        onDismissed: (_) => NotificationRepository.instance.remove(n.id),
                        child: _NotificationTile(notification: n),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !notification.read;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        NotificationRepository.instance.markRead(notification.id);
        final pid = notification.paintingId;
        if (pid != null) context.push('/painting/$pid');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: scheme.surfaceContainerHighest.withValues(
            alpha: unread ? 0.9 : 0.55,
          ),
          border: unread
              ? Border.all(color: scheme.primary.withValues(alpha: 0.35))
              : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconFor(notification.type, scheme),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM d, HH:mm',
                        ).format(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _iconFor(String type, ColorScheme scheme) {
    final (icon, color) = switch (type) {
      'upload' => (Icons.add_photo_alternate_outlined, scheme.primary),
      'backup' => (Icons.backup_outlined, const Color(0xFF22C55E)),
      'duplicate' => (Icons.content_copy, const Color(0xFFF59E0B)),
      'sync' => (Icons.sync, const Color(0xFF3B82F6)),
      'document' => (Icons.description_outlined, scheme.tertiary),
      _ => (Icons.notifications_outlined, scheme.onSurface),
    };
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
