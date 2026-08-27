import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_spacing.dart';

/// Premium bottom navigation bar with 3D depth, floating indicator,
/// and spring animations on tap.
class PremiumNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;

  const PremiumNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<PremiumNavBar> createState() => _PremiumNavBarState();
}

class _PremiumNavBarState extends State<PremiumNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorScale;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _indicatorScale = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.elasticOut,
    );
    _indicatorController.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _indicatorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          // Subtle glow at top
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.items.length; i++)
            Expanded(
              child: _NavBarItem(
                item: widget.items[i],
                selected: i == widget.currentIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTap(i);
                },
                indicatorScale: i == widget.currentIndex
                    ? _indicatorScale
                    : null,
                color: scheme.primary,
                unselectedColor: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumNavItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const PremiumNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final PremiumNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Animation<double>? indicatorScale;
  final Color color;
  final Color unselectedColor;

  const _NavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.indicatorScale,
    required this.color,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayIcon = selected ? (item.selectedIcon ?? item.icon) : item.icon;
    final itemColor = selected ? color : unselectedColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with floating indicator
          SizedBox(
            width: 48,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating indicator pill
                if (selected && indicatorScale != null)
                  AnimatedBuilder(
                    animation: indicatorScale!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: indicatorScale!.value,
                        child: Container(
                          width: 48,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    },
                  ),
                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    displayIcon,
                    key: ValueKey(selected),
                    size: 22,
                    color: itemColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: itemColor,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
