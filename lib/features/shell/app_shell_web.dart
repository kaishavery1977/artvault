import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/web/web_breadcrumb.dart';

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
      backgroundColor: isDark ? const Color(0xFF08090F) : const Color(0xFFF8F8FC),
      body: Row(
        children: [
          // Immersive sidebar
          _WebSidebar(
            index: shell.currentIndex,
            onSelect: _go,
            destinations: _destinations,
            hoveredIndex: _hoveredIndex,
            onHover: (i) => setState(() => _hoveredIndex = i),
            onHoverExit: () => setState(() => _hoveredIndex = -1),
          ),
          // Main content with smooth transition
          Expanded(
            child: Column(
              children: [
                // Top header bar
                _WebHeader(
                  currentIndex: shell.currentIndex,
                  onSearch: () => context.push('/search'),
                  onNotifications: () => context.push('/notifications'),
                  canEdit: canEdit,
                  onUpload: () => context.push('/painting/new'),
                ),
                // Breadcrumb navigation
                const WebBreadcrumb(),
                // Page content with scroll-to-top
                Expanded(
                  child: Stack(
                    children: [
                      content,
                    ],
                  ),
                ),
              ],
            ),
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
      width: 72,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.secondary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.palette_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 24),
          // Navigation items
          Expanded(
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
              ],
            ),
          ),
          // Bottom: user avatar
          const SizedBox(height: 16),
          _SidebarAvatar(),
          const SizedBox(height: 20),
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

    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : isHovered
                    ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                child: Icon(
                  isSelected ? dest.selected : dest.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dest.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
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

    return MouseRegion(
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
            // Upload button
            MouseRegion(
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
