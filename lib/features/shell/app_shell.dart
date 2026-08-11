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
  (icon: Icons.space_dashboard_outlined, selected: Icons.space_dashboard, label: 'Home'),
  (icon: Icons.grid_view_outlined, selected: Icons.grid_view_rounded, label: 'Gallery'),
  (icon: Icons.person_outline, selected: Icons.person_rounded, label: 'Artists'),
  (icon: Icons.description_outlined, selected: Icons.description_rounded, label: 'Documents'),
  (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Settings'),
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
          : NavigationBar(
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
      floatingActionButton: canEdit
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
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
