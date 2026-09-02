import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/a11y.dart';
import '../../core/widgets/web/pwa_install_banner.dart';
import '../../core/widgets/web/web_breadcrumb.dart';
import '../../core/widgets/web/sync_status_indicator.dart';

/// Web-optimized application shell with immersive sidebar navigation,
/// smooth page transitions, hover effects, and 60fps animations.
///
/// This shell is only used on web (kIsWeb). Mobile uses the original AppShell.
class AppShellWeb extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellWeb({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShellWeb> createState() => _AppShellWebState();
}

class _AppShellWebState extends ConsumerState<AppShellWeb>
    with TickerProviderStateMixin {
  late final AnimationController _pageIn;
  late final AnimationController _sidebarHover;
  int _hoveredIndex = -1;
  final FocusNode _mainContentFocusNode = FocusNode();

  static const _destinations = [
    _NavDest(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Home', Color(0xFF8B5CF6)),
    _NavDest(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Gallery', Color(0xFF22D3EE)),
    _NavDest(Icons.person_outline, Icons.person_rounded, 'Artists', Color(0xFFFB7185)),
    _NavDest(Icons.description_outlined, Icons.description_rounded, 'Documents', Color(0xFFFBBF24)),
    _NavDest(Icons.settings_outlined, Icons.settings_rounded, 'Settings', Color(0xFF6EE7B7)),
  ];

  @override
  void initState() {
    super.initState();
    _pageIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );
    _sidebarHover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(covariant AppShellWeb old) {
    super.didUpdateWidget(old);
    if (old.navigationShell.currentIndex != widget.navigationShell.currentIndex) {
      _pageIn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pageIn.dispose();
    _sidebarHover.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = _WebPageTransition(
      animation: _pageIn,
      child: shell,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05070F) : const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          // Skip navigation link for keyboard users (visually hidden until focused)
          SkipNavigation(contentFocusNode: _mainContentFocusNode),
          // Ambient 3D orbs behind everything
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -80,
                    left: -60,
                    child: Container(
                      width: 420,
                      height: 420,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.violet500.withValues(alpha: isDark ? 0.18 : 0.10),
                            AppColors.violet500.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -80,
                    child: Container(
                      width: 560,
                      height: 560,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.cyan400.withValues(alpha: isDark ? 0.14 : 0.08),
                            AppColors.cyan400.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              // Premium 3D sidebar with navigation landmark for screen readers
              Semantics(
                explicitChildNodes: true,
                label: 'Main navigation',
                child: _WebSidebar(
                index: shell.currentIndex,
                onSelect: _go,
                destinations: _destinations,
                hoveredIndex: _hoveredIndex,
                onHover: (i) => setState(() => _hoveredIndex = i),
                onHoverExit: () => setState(() => _hoveredIndex = -1),
              ),
              ),
              // Main content with glass + depth
              Expanded(
                child: Column(
                  children: [
                    // PWA install prompt banner
                    const PwaInstallBanner(),
                    _WebHeader(
                      currentIndex: shell.currentIndex,
                      onSearch: () => context.push('/search'),
                      onNotifications: () => context.push('/notifications'),
                      canEdit: canEdit,
                      onUpload: () => context.push('/painting/new'),
                    ),
                    const WebBreadcrumb(),
                    Expanded(
                      child: Focus(
                        focusNode: _mainContentFocusNode,
                        child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 32, offset: const Offset(0, 16)),
                            BoxShadow(color: AppColors.violet500.withValues(alpha: isDark ? 0.08 : 0.04), blurRadius: 48, offset: const Offset(0, 8)),
                          ],
                        ),
                        clipBehavior: Clip.none,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Semantics(
                            label: 'Main content area',
                            child: content,
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

class _NavDest {
  final IconData icon;
  final IconData selected;
  final String label;
  final Color color;
  const _NavDest(this.icon, this.selected, this.label, this.color);
}

/// Immersive web sidebar with animated hover effects and smooth transitions.
class _WebSidebar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<_NavDest> destinations;
  final int hoveredIndex;
  final ValueChanged<int> onHover;
  final VoidCallback onHoverExit;

  const _WebSidebar({
    required this.index,
    required this.onSelect,
    required this.destinations,
    required this.hoveredIndex,
    required this.onHover,
    required this.onHoverExit,
  });

  @override
  State<_WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<_WebSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorCtrl;

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant _WebSidebar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _indicatorCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111A).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.82),
        border: Border(
          right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(8, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo + wordmark with glow
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.secondary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
                      BoxShadow(color: AppColors.violet500.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.palette_rounded, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ArtVault', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    Text('Private Gallery • 3D', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0)]))),
          ),
          const SizedBox(height: 16),
          // Navigation + admin — scrollable so no overflow on short screens
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < widget.destinations.length; i++)
                    _SidebarItem(
                      dest: widget.destinations[i],
                      isSelected: i == widget.index,
                      isHovered: i == widget.hoveredIndex,
                      onTap: () => widget.onSelect(i),
                      onHover: () => widget.onHover(i),
                      onHoverExit: widget.onHoverExit,
                    ),
                  _AdminSidebarSection(),
                ],
              ),
            ),
          ),
          // Bottom: user avatar (always visible)
          const SizedBox(height: 12),
          _SidebarAvatar(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavDest dest;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onHoverExit;

  const _SidebarItem({
    required this.dest,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onHover,
    required this.onHoverExit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dest.color;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: '${dest.label}${isSelected ? ', current page' : ''}',
      selected: isSelected,
      button: true,
      child: MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.14) : isHovered ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent, width: 1),
            boxShadow: isSelected ? [BoxShadow(color: activeColor.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6)), BoxShadow(color: activeColor.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, 12))] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.16) : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? activeColor.withValues(alpha: 0.22) : Colors.transparent),
                ),
                child: Icon(isSelected ? dest.selected : dest.icon, size: 18, color: isSelected ? activeColor : inactiveColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dest.label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Container(width: isSelected ? 24 : 0, height: 2, decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.chevron_right_rounded, size: 16, color: activeColor.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _SidebarAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'User profile for ${user?.displayName ?? 'Guest'}. Tap to open settings.',
      button: true,
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/settings'),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.violet500.withValues(alpha: 0.3),
                AppColors.cyan400.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              (user?.displayName ?? 'G')[0].toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Admin section in sidebar — shows Users & Activity Log for admin users.
class _AdminSidebarSection extends ConsumerWidget {
  const _AdminSidebarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider.select((a) => a.canManageUsers));
    if (!canManage) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currentPath = GoRouterState.of(context).uri.path;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 8),
        // Admin label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ADMIN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Admin Dashboard
        _AdminLink(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
          color: const Color(0xFF8B5CF6),
          isSelected: currentPath == '/admin-dashboard',
          onTap: () => context.push('/admin-dashboard'),
        ),
        // Users
        _AdminLink(
          icon: Icons.admin_panel_settings,
          label: 'Users & Roles',
          color: const Color(0xFF22D3EE),
          isSelected: currentPath == '/users',
          onTap: () => context.push('/users'),
        ),
        // Activity Log
        _AdminLink(
          icon: Icons.history,
          label: 'Activity Log',
          color: const Color(0xFF22D3EE),
          isSelected: currentPath == '/activity-log',
          onTap: () => context.push('/activity-log'),
        ),
        // Backup
        _AdminLink(
          icon: Icons.backup_outlined,
          label: 'Backup',
          color: const Color(0xFF6EE7B7),
          isSelected: currentPath == '/backup',
          onTap: () => context.push('/backup'),
        ),
      ],
    );
  }
}

class _AdminLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web header bar with search, notifications, and upload button.
class _WebHeader extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool canEdit;
  final VoidCallback onUpload;

  const _WebHeader({
    required this.currentIndex,
    required this.onSearch,
    required this.onNotifications,
    required this.canEdit,
    required this.onUpload,
  });

  static const _titles = ['Home', 'Gallery', 'Artists', 'Documents', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Page title
          Text(
            _titles[currentIndex],
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Sync status
          const SyncStatusIndicator(),
          const SizedBox(width: 12),
          // Search button
          _HeaderButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onTap: onSearch,
          ),
          const SizedBox(width: 8),
          // Notifications
          _HeaderButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            onTap: onNotifications,
          ),
          const SizedBox(width: 8),
          // Theme toggle
          _ThemeToggle(),
          if (canEdit) ...[
            const SizedBox(width: 12),
            // Upload button with semantic label
            Semantics(
              button: true,
              label: 'Upload new artwork',
              child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Colors.white),
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
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Smooth page transition wrapper with fade + slide.
class _WebPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _WebPageTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.01),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}

/// Dark/Light mode toggle button for the web header.
class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).state =
              isDark ? ThemeMode.light : ThemeMode.dark;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 18,
            color: isDark ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
