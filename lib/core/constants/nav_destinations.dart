import 'package:flutter/material.dart';

import 'app_colors.dart';

/// One destination in the primary application navigation.
///
/// Instances are const and live in [kAppDestinations] — the single source
/// of truth shared by the mobile shell (bottom [NavigationBar] / desktop
/// rail in `app_shell.dart`) and the web shell (`app_shell_web.dart`).
class AppNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;

  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
  });
}

/// The five primary destinations, each with its own accent hue so nav
/// items stay distinguishable at a glance (violet/cyan/rose/amber/emerald).
const List<AppNavDestination> kAppDestinations = [
  AppNavDestination(
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    label: 'Home',
    color: AppColors.violet400,
  ),
  AppNavDestination(
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
    label: 'Gallery',
    color: AppColors.cyan400,
  ),
  AppNavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person_rounded,
    label: 'Artists',
    color: AppColors.rose400,
  ),
  AppNavDestination(
    icon: Icons.description_outlined,
    selectedIcon: Icons.description_rounded,
    label: 'Documents',
    color: AppColors.amber400,
  ),
  AppNavDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: 'Settings',
    color: AppColors.emerald400,
  ),
];
