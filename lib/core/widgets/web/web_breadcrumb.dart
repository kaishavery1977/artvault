import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


/// Breadcrumb navigation bar for web — shows current location.
class WebBreadcrumb extends StatelessWidget {
  const WebBreadcrumb({super.key});

  static const _routeLabels = {
    '/home': 'Home',
    '/gallery': 'Gallery',
    '/artists': 'Artists',
    '/documents': 'Documents',
    '/settings': 'Settings',
    '/reports': 'Reports',
    '/notifications': 'Notifications',
    '/search': 'Search',
    '/about': 'About',
    '/backup': 'Backup',
    '/users': 'Users',
    '/activity-log': 'Activity Log',
    '/security': 'Security',
    '/storage': 'Storage',
    '/profile': 'Profile',
    '/scan': 'Scan',
    '/upgrade': 'Upgrade',
    '/changelog': 'Changelog',
    '/trash': 'Trash',
  };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      child: Row(
        children: [
          // Home icon
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Icon(
              Icons.home_rounded,
              size: 16,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          // Breadcrumb segments
          for (var i = 0; i < segments.length; i++) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                final path = '/${segments.sublist(0, i + 1).join('/')}';
                context.go(path);
              },
              child: Text(
                _routeLabels['/${segments[i]}'] ?? segments[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == segments.length - 1
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: i == segments.length - 1
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
