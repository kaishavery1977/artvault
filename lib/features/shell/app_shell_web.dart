import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/nav_destinations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/a11y.dart';
import '../../core/widgets/web/pwa_install_banner.dart';
import '../../core/widgets/web/sync_status_indicator.dart';

/// Web-optimized application shell with a slim floating glass rail and a
/// unified top bar. Only used on web (kIsWeb); mobile uses [AppShell].
///
/// Design intent — premium, not console:
///  - The rail floats over the ambient background (rounded glass, hairline
///    border) and is compact by default; it expands to labeled items while
///    hovered so destinations stay discoverable without a permanent 260px
///    chrome column.
///  - A single top bar owns the current page title + global actions
///    (sync, search, notifications, theme, upload); the old separate
///    breadcrumb row is gone because pushed routes replace this shell.
///  - Content is full-bleed over the theme background (no nested framed
///    card) — screens bring their own cards/surfaces.
///  - Reduced motion renders all transitions statically.
class AppShellWeb extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellWeb({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShellWeb> createState() => _AppShellWebState();
}

class _AppShellWebState extends ConsumerState<AppShellWeb>
    with TickerProviderStateMixin {
  late final AnimationController _pageIn;
  final FocusNode _mainContentFocusNode = FocusNode();
  bool _railExpanded = false;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _pageIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AppShellWeb old) {
    super.didUpdateWidget(old);
    if (old.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      final motionOk = !MediaQuery.disableAnimationsOf(context);
      if (motionOk) _pageIn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pageIn.dispose();
    _mainContentFocusNode.dispose();
    super.dispose();
  }

  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (index != widget.navigationShell.currentIndex) {
      ref.invalidate(paintingsProvider);
      ref.invalidate(artistsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(vaultStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));
    final canManage = ref.watch(authProvider.select((a) => a.canManageUsers));
    final currentIndex = shell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: Stack(
        children: [
          SkipNavigation(contentFocusNode: _mainContentFocusNode),
          // Ambient aurora wash behind the glass rail + content.
          Positioned.fill(
            child: IgnorePointer(child: _ShellAtmosphere(isDark: isDark)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slim floating glass rail (auto-expands while hovered).
              MouseRegion(
                onEnter: (_) {
                  if (!MediaQuery.disableAnimationsOf(context)) {
                    setState(() => _railExpanded = true);
                  }
                },
                onExit: (_) => setState(() => _railExpanded = false),
                child: _FloatingRail(
                  index: currentIndex,
                  onSelect: _go,
                  expanded: _railExpanded,
                  hoveredIndex: _hoveredIndex,
                  onHover: (i) => setState(() => _hoveredIndex = i),
                  onHoverExit: () => setState(() => _hoveredIndex = -1),
                  canManage: canManage,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PwaInstallBanner(),
                    _UnifiedTopBar(
                      currentIndex: currentIndex,
                      onSearch: () => context.push('/search'),
                      onNotifications: () => context.push('/notifications'),
                      canEdit: canEdit,
                      onUpload: () => context.push('/painting/new'),
                    ),
                    Expanded(
                      child: Focus(
                        focusNode: _mainContentFocusNode,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Semantics(
                            label: 'Main content area',
                            child: _WebPageTransition(
                              animation: _pageIn,
                              child: shell,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft, theme-aware color wash behind everything — static gradients only
/// (no per-frame work), so it is free on mid-range devices.
class _ShellAtmosphere extends StatelessWidget {
  final bool isDark;

  const _ShellAtmosphere({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -140,
          right: -80,
          child: _glow(
            size: 520,
            color: AppColors.violet500.withValues(alpha: isDark ? 0.10 : 0.07),
          ),
        ),
        Positioned(
          bottom: -160,
          left: 120,
          child: _glow(
            size: 560,
            color: AppColors.cyan400.withValues(alpha: isDark ? 0.07 : 0.05),
          ),
        ),
      ],
    );
  }

  Widget _glow({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Floating rounded glass rail. Compact (icon-only) by default; expands to
/// show labels while hovered.
class _FloatingRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final bool expanded;
  final int hoveredIndex;
  final ValueChanged<int> onHover;
  final VoidCallback onHoverExit;
  final bool canManage;

  const _FloatingRail({
    required this.index,
    required this.onSelect,
    required this.expanded,
    required this.hoveredIndex,
    required this.onHover,
    required this.onHoverExit,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      explicitChildNodes: true,
      label: 'Main navigation',
      container: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: expanded ? 232 : 78,
        margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark
              ? const Color(0xFF10121C).withValues(alpha: 0.78)
              : Colors.white.withValues(alpha: 0.82),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 28,
              offset: const Offset(6, 12),
            ),
            BoxShadow(
              color: AppColors.violet500.withValues(
                alpha: isDark ? 0.10 : 0.05,
              ),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RailBrand(expanded: expanded),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < kAppDestinations.length; i++)
                          _RailItem(
                            dest: kAppDestinations[i],
                            isSelected: i == index,
                            isHovered: i == hoveredIndex,
                            expanded: expanded,
                            onTap: () => onSelect(i),
                            onHover: () => onHover(i),
                            onHoverExit: onHoverExit,
                          ),
                        _AdminRailSection(
                          expanded: expanded,
                          canManage: canManage,
                        ),
                      ],
                    ),
                  ),
                ),
                _RailUser(expanded: expanded),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  final bool expanded;
  const _RailBrand({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        expanded ? 14 : 15,
        18,
        expanded ? 14 : 15,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.violet500, AppColors.cyan400],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet500.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.palette_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ArtVault',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    L10n.t(context, 'Private Gallery'),
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One rail item: pill icon (collapsed) or icon + label (expanded).
class _RailItem extends StatelessWidget {
  final AppNavDestination dest;
  final bool isSelected;
  final bool isHovered;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onHoverExit;

  const _RailItem({
    required this.dest,
    required this.isSelected,
    required this.isHovered,
    required this.expanded,
    required this.onTap,
    required this.onHover,
    required this.onHoverExit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: expanded ? 12 : 14, vertical: 3),
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 0,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? dest.color.withValues(alpha: isDark ? 0.16 : 0.13)
            : isHovered
            ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? dest.color.withValues(alpha: isDark ? 0.30 : 0.28)
              : Colors.transparent,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: dest.color.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        // Compact (icon-only) rail: center the icon inside its pill — the
        // stretched container otherwise anchors the tile to the pill's left
        // edge, leaving the icon looking pushed left of the rail's middle.
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          // Icon tile
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        dest.color.withValues(alpha: 0.22),
                        dest.color.withValues(alpha: 0.08),
                      ],
                    )
                  : null,
            ),
            child: Center(
              child: Icon(
                isSelected ? dest.selectedIcon : dest.icon,
                size: 18,
                color: isSelected ? dest.color : inactiveColor,
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                L10n.t(context, dest.label),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? dest.color
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: dest.color.withValues(alpha: 0.8),
              ),
          ],
        ],
      ),
    );

    final child = Semantics(
      label:
          '${L10n.t(context, dest.label)}'
          '${isSelected ? ', ${L10n.t(context, 'current page')}' : ''}',
      selected: isSelected,
      button: true,
      child: MouseRegion(
        onEnter: (_) => onHover(),
        onExit: (_) => onHoverExit(),
        cursor: SystemMouseCursors.click,
        child: KeyboardActivatable(
          onActivate: onTap,
          semanticsLabel: L10n.t(context, dest.label),
          child: GestureDetector(onTap: onTap, child: content),
        ),
      ),
    );

    // Tooltip supplies the label while the rail is collapsed.
    if (!expanded && !isSelected) {
      return Tooltip(
        message: L10n.t(context, dest.label),
        waitDuration: const Duration(milliseconds: 450),
        child: child,
      );
    }
    return child;
  }
}

/// Admin destinations (Users, Activity Log, Backup, Dashboard) — icon-only
/// when the rail is collapsed, labeled rows when expanded.
class _AdminRailSection extends StatelessWidget {
  final bool expanded;
  final bool canManage;

  const _AdminRailSection({required this.expanded, required this.canManage});

  @override
  Widget build(BuildContext context) {
    if (!canManage) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currentPath = GoRouterState.of(context).uri.path;

    final links = [
      (
        'Dashboard',
        Icons.dashboard_outlined,
        '/admin-dashboard',
        AppColors.violet400,
      ),
      (
        'Users & Roles',
        Icons.admin_panel_settings_outlined,
        '/users',
        AppColors.cyan400,
      ),
      (
        'Activity Log',
        Icons.history_rounded,
        '/activity-log',
        AppColors.rose400,
      ),
      ('Backup', Icons.backup_outlined, '/backup', AppColors.emerald400),
    ];

    return Column(
      children: [
        const SizedBox(height: 10),
        if (expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.3)),
          )
        else
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        const SizedBox(height: 8),
        for (final (label, icon, path, color) in links)
          _AdminRailLink(
            icon: icon,
            label: label,
            color: color,
            expanded: expanded,
            isSelected: currentPath == path,
            onTap: () => context.push(path),
          ),
      ],
    );
  }
}

class _AdminRailLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool expanded;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminRailLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.expanded,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.symmetric(horizontal: expanded ? 12 : 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Icon(
              icon,
              size: 17,
              color: isSelected
                  ? color
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : isDark
                    ? Colors.white.withValues(alpha: 0.65)
                    : Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );

    final child = Semantics(
      label: label,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: KeyboardActivatable(
          onActivate: onTap,
          semanticsLabel: label,
          child: GestureDetector(onTap: onTap, child: row),
        ),
      ),
    );

    if (!expanded) {
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 450),
        child: child,
      );
    }
    return child;
  }
}

/// Signed-in user chip at the rail's foot — avatar (collapsed) or
/// avatar + name (expanded). Opens Settings.
class _RailUser extends ConsumerWidget {
  final bool expanded;
  const _RailUser({required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'User profile for ${user?.displayName ?? 'Guest'}. Tap to open settings.',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.push('/settings'),
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 16,
              vertical: 4,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 8 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.violet500.withValues(alpha: 0.35),
                        AppColors.cyan400.withValues(alpha: 0.35),
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (user?.displayName ?? 'G')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user?.displayName ?? 'Guest',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified glass top bar: page title on the left, global actions on the right.
class _UnifiedTopBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool canEdit;
  final VoidCallback onUpload;

  const _UnifiedTopBar({
    required this.currentIndex,
    required this.onSearch,
    required this.onNotifications,
    required this.canEdit,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final title = kAppDestinations[currentIndex].label;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              L10n.t(context, title),
              key: ValueKey(title),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          const SyncStatusIndicator(),
          const SizedBox(width: 10),
          _TopAction(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onTap: onSearch,
          ),
          const SizedBox(width: 6),
          _TopAction(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            onTap: onNotifications,
          ),
          const SizedBox(width: 6),
          const _ThemeToggle(),
          if (canEdit) ...[
            const SizedBox(width: 10),
            _UploadCta(onTap: onUpload),
          ],
        ],
      ),
    );
  }
}

/// Small circular glass action with hover/press feedback.
class _TopAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TopAction> createState() => _TopActionState();
}

class _TopActionState extends State<_TopAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.06,
                    )
                  : (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.03,
                    ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: _hovered
                    ? scheme.primary.withValues(alpha: 0.25)
                    : (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.06,
                      ),
              ),
            ),
            child: Icon(widget.icon, size: 19, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Primary upload CTA in the top bar.
class _UploadCta extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Upload new artwork',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

/// Smooth tab-change transition: fade + gentle drift. Reduced motion
/// renders statically.
class _WebPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _WebPageTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.008), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }
}

/// Dark/Light toggle with a smooth icon cross-fade.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            ref.read(themeModeProvider.notifier).state = isDark
                ? ThemeMode.light
                : ThemeMode.dark;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                size: 17,
                color: isDark ? AppColors.amber300 : scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
