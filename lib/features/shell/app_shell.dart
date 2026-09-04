import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/nav_destinations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/device_resolution_service.dart';
import '../../core/providers/providers.dart';
import 'app_shell_web.dart';

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

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Drives a quick fade+drift whenever the active tab changes.
  late final AnimationController _tabIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  /// Drives a gentle pulse on the FAB when the gallery is empty.
  late final AnimationController _fabPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    // Refresh providers when switching tabs so data stays in sync.
    if (index != widget.navigationShell.currentIndex) {
      ref.invalidate(paintingsProvider);
      ref.invalidate(artistsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(vaultStatsProvider);
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex;
    // Respect reduced motion: keep the switch instant for those users.
    if (changed && !MediaQuery.disableAnimationsOf(context)) {
      _tabIn.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    // Start FAB pulse loop after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFabPulseIfNeeded();
    });
  }

  void _startFabPulseIfNeeded() {
    final paintingsAsync = ref.read(paintingsProvider);
    final paintings = paintingsAsync.valueOrNull ?? [];
    final hasPaintings = paintings.any((p) => !p.isDeleted);
    if (!hasPaintings && !MediaQuery.disableAnimationsOf(context)) {
      _fabPulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _tabIn.dispose();
    _fabPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web uses the dedicated web shell — never touch mobile code paths.
    if (kIsWeb) {
      return AppShellWeb(navigationShell: widget.navigationShell);
    }

    final shell = widget.navigationShell;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));
    // Adaptive nav bar height: compact phones get 56dp, standard 60dp,
    // tablets and larger get 68dp.
    final deviceSize = DeviceResolutionService.instance.current?.size;
    final navBarHeight = switch (deviceSize) {
      DeviceSize.compact => 56.0,
      DeviceSize.standard || DeviceSize.large => 60.0,
      _ => 68.0,
    };

    final content = SafeArea(
      top: false,
      child: FadeTransition(
        opacity: _tabIn,
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.008),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: _tabIn, curve: Curves.easeOutCubic),
              ),
          child: shell,
        ),
      ),
    );

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
                height: navBarHeight,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                indicatorColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.18),
                animationDuration: const Duration(milliseconds: 400),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final d in kAppDestinations)
                    NavigationDestination(
                      icon: Icon(
                        d.icon,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      selectedIcon: Icon(d.selectedIcon, color: d.color),
                      label: L10n.t(context, d.label),
                    ),
                ],
              ),
            ),
      floatingActionButton:
          canEdit && !isOwnFabTab && !ref.watch(gallerySelectModeProvider)
          ? AnimatedBuilder(
              animation: _fabPulse,
              builder: (context, child) {
                final scale = 1.0 + _fabPulse.value * 0.04;
                return Transform.scale(scale: scale, child: child);
              },
              child: FloatingActionButton.extended(
                heroTag: 'quick_add',
                onPressed: () => context.push('/painting/new'),
                icon: const Icon(Icons.add),
                label: const Text('Upload'),
              ),
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
          for (final d in kAppDestinations)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: Text(L10n.t(context, d.label)),
            ),
        ],
      ),
    );
  }
}
