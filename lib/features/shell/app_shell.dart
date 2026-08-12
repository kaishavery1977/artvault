import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/providers/providers.dart';

/// Responsive application shell.
///
/// - Phones: bottom [NavigationBar] (Material 3) + floating quick-add.
/// - Tablets / foldables / desktops: persistent [NavigationRail] + wider
///   canvas with the upload action surfaced in the header area.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

const _shellDestinations = [
  (
    icon: Icons.space_dashboard_outlined,
    selected: Icons.space_dashboard,
    label: 'Home',
  ),
  (
    icon: Icons.grid_view_outlined,
    selected: Icons.grid_view_rounded,
    label: 'Gallery',
  ),
  (
    icon: Icons.person_outline,
    selected: Icons.person_rounded,
    label: 'Artists',
  ),
  (
    icon: Icons.description_outlined,
    selected: Icons.description_rounded,
    label: 'Documents',
  ),
  (
    icon: Icons.settings_outlined,
    selected: Icons.settings_rounded,
    label: 'Settings',
  ),
];

class _AppShellState extends ConsumerState<AppShell> {
  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final canEdit = ref.watch(authProvider).canEdit;

    final content = SafeArea(top: false, child: shell);

    // Artists and Documents tabs have their own FABs; showing the shell's
    // quick-add here would overlap them at the bottom-right corner.
    final isOwnFabTab = shell.currentIndex == 2 || shell.currentIndex == 3;

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                _DesktopNav(
                  index: shell.currentIndex,
                  onSelect: _go,
                  canEdit: canEdit,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isDesktop
          ? null
          : _GlassNavBar(
              child: NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                destinations: [
                  for (final d in _shellDestinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: d.label,
                    ),
                ],
              ),
            ),
      floatingActionButton: canEdit && !isOwnFabTab
          ? FloatingActionButton.extended(
              heroTag: 'quick_add',
              onPressed: () => context.push('/painting/new'),
              icon: const Icon(Icons.add),
              label: const Text('Upload'),
            )
          : null,
    );
  }
}

/// Frosted-glass wrapper for the bottom navigation bar.
///
/// The [BackdropFilter] blurs the ambient gradient behind the bar — a single
/// static strip, so the blur cost is negligible and nothing scrolls under it
/// (layout stays identical, so no overflow or occlusion risk).
class _GlassNavBar extends StatelessWidget {
  final Widget child;

  const _GlassNavBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final edge = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: edge, width: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DesktopNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final bool canEdit;

  const _DesktopNav({
    required this.index,
    required this.onSelect,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.cardColor,
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.palette, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'ArtVault',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        trailing: const SizedBox(height: AppSpacing.xl),
        destinations: [
          for (final d in _shellDestinations)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: Text(d.label),
            ),
        ],
      ),
    );
  }
}
