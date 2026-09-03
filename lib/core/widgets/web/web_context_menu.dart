import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

/// Right-click context menu for paintings on web.
/// Shows edit, delete, share, download options.
class WebContextMenu extends StatelessWidget {
  final String paintingId;
  final String paintingTitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final Widget child;

  const WebContextMenu({
    super.key,
    required this.paintingId,
    required this.paintingTitle,
    required this.child,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
      child: child,
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      color: isDark ? const Color(0xFF1C1F30) : Colors.white,
      items: [
        _menuItem(
          context,
          icon: Icons.open_in_new_rounded,
          label: 'View details',
          onTap: () => context.push('/painting/$paintingId'),
        ),
        _menuItem(
          context,
          icon: Icons.edit_rounded,
          label: 'Edit painting',
          onTap: onEdit ?? () => context.push('/painting/edit/$paintingId'),
        ),
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            height: 1,
            child: Divider(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        _menuItem(
          context,
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: onShare,
        ),
        _menuItem(
          context,
          icon: Icons.download_rounded,
          label: 'Download',
          onTap: onDownload,
        ),
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            height: 1,
            child: Divider(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        _menuItem(
          context,
          icon: Icons.delete_rounded,
          label: 'Delete',
          color: AppColors.error,
          onTap: onDelete,
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return PopupMenuItem<String>(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
