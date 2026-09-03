import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import '../../core/widgets/premium/premium.dart';
import '../gallery/painting_card.dart';

/// Web-optimized home screen with immersive hero section, hover effects,
/// smooth transitions, and 60fps animations throughout.
class HomeScreenWeb extends ConsumerWidget {
  const HomeScreenWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final paintingsAsync = ref.watch(paintingsProvider);
    final canEdit = auth.canEdit;

    final paintings = (paintingsAsync.valueOrNull ?? const <Painting>[])
        .where((p) => !p.isDeleted)
        .toList();
    final recent = [...paintings]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return CustomScrollView(
      slivers: [
        // Hero section
        SliverToBoxAdapter(
          child: _WebHero(
            userName: auth.user?.displayName ?? 'Guest',
            paintings: paintings,
            canEdit: canEdit,
          ),
        ),
        // Stats row
        SliverToBoxAdapter(
          child: _StatsRow(paintings: paintings, ref: ref),
        ),
        // Quick actions
        SliverToBoxAdapter(child: _QuickActionsWeb(canEdit: canEdit)),
        // Recent uploads header
        if (paintings.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
              child: Row(
                children: [
                  Text(
                    'Recent Uploads',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/gallery'),
                    child: const Text('View all →'),
                  ),
                ],
              ),
            ),
          ),
        // Painting grid
        if (paintings.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _HoverPaintingCard(painting: recent.take(8).toList()[i]),
                childCount: recent.take(8).length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
            ),
          ),
        // AI Insights
        if (paintings.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _AiInsightsWeb(paintings: paintings),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

/// Immersive hero section for the web home screen.
class _WebHero extends ConsumerWidget {
  final String userName;
  final List<Painting> paintings;
  final bool canEdit;

  const _WebHero({
    required this.userName,
    required this.paintings,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.violet900.withValues(alpha: 0.4),
                  AppColors.cyan900.withValues(alpha: 0.2),
                  AppColors.rose900.withValues(alpha: 0.15),
                ]
              : [
                  AppColors.violet100.withValues(alpha: 0.8),
                  AppColors.cyan100.withValues(alpha: 0.5),
                  AppColors.rose100.withValues(alpha: 0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Left: text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greeting()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                GradientShimmerText(
                  text: 'Hello, $userName',
                  style: AppTheme.display(context, size: 32),
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                  duration: const Duration(milliseconds: 1200),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your art collection at a glance',
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 24),
                // Stat pills
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _StatPill(
                      icon: Icons.brush,
                      label: 'Artworks',
                      value: '${paintings.length}',
                      color: AppColors.cyan500,
                    ),
                    _StatPill(
                      icon: Icons.attach_money,
                      label: 'Value',
                      value: Formatters.money(
                        paintings.fold<double>(
                          0.0,
                          (s, p) => s + (p.price ?? 0),
                        ),
                      ),
                      color: AppColors.amber500,
                    ),
                    _StatPill(
                      icon: Icons.description,
                      label: 'Documents',
                      value:
                          '${ref.watch(documentsProvider).valueOrNull?.length ?? 0}',
                      color: AppColors.emerald500,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: decorative palette icon
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              )
              .animate()
              .scaleXY(begin: 0.8, duration: 800.ms, curve: Curves.easeOutBack)
              .then()
              .shimmer(
                duration: 2000.ms,
                color: Colors.white.withValues(alpha: 0.2),
              ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.03);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _StatPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  State<_StatPill> createState() => _StatPillState();
}

class _StatPillState extends State<_StatPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.15)
                : widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : widget.color.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: widget.color,
                    ),
                  ),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stats row for the web home screen.
class _StatsRow extends StatelessWidget {
  final List<Painting> paintings;
  final WidgetRef ref;

  const _StatsRow({required this.paintings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Stats are in the hero now
  }
}

/// Quick actions row for web with hover effects.
class _QuickActionsWeb extends ConsumerWidget {
  final bool canEdit;
  const _QuickActionsWeb({required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_WebAction>[
      if (canEdit)
        _WebAction(
          Icons.add_photo_alternate,
          'Upload',
          () => context.push('/painting/new'),
          AppColors.emerald500,
        ),
      _WebAction(
        Icons.grid_view,
        'Gallery',
        () => context.go('/gallery'),
        AppColors.cyan500,
      ),
      _WebAction(
        Icons.person,
        'Artists',
        () => context.go('/artists'),
        AppColors.rose500,
      ),
      _WebAction(
        Icons.insights,
        'Reports',
        () => context.push('/reports'),
        AppColors.amber500,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _WebActionCard(action: actions[i])),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }
}

class _WebAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _WebAction(this.icon, this.label, this.onTap, this.color);
}

class _WebActionCard extends StatefulWidget {
  final _WebAction action;
  const _WebActionCard({required this.action});

  @override
  State<_WebActionCard> createState() => _WebActionCardState();
}

class _WebActionCardState extends State<_WebActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? action.color.withValues(alpha: 0.12)
                : action.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? action.color.withValues(alpha: 0.25)
                  : action.color.withValues(alpha: 0.1),
              width: 0.8,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hovered ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(action.icon, size: 24, color: action.color),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: action.color.withValues(alpha: _hovered ? 1.0 : 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painting card with hover zoom effect for web.
class _HoverPaintingCard extends StatefulWidget {
  final Painting painting;
  const _HoverPaintingCard({required this.painting});

  @override
  State<_HoverPaintingCard> createState() => _HoverPaintingCardState();
}

class _HoverPaintingCardState extends State<_HoverPaintingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/painting/${widget.painting.id}'),
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: PaintingGridCard(painting: widget.painting),
          ),
        ),
      ),
    );
  }
}

/// AI Insights card for web.
class _AiInsightsWeb extends StatelessWidget {
  final List<Painting> paintings;
  const _AiInsightsWeb({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final mediumCounts = <String, int>{};
    final artistCounts = <String, int>{};
    for (final p in paintings) {
      if (p.medium.isNotEmpty) {
        mediumCounts[p.medium] = (mediumCounts[p.medium] ?? 0) + 1;
      }
      if (p.artistName.isNotEmpty) {
        artistCounts[p.artistName] = (artistCounts[p.artistName] ?? 0) + 1;
      }
    }

    String? topKey(Map<String, int> c) {
      String? best;
      var bestCount = 0;
      c.forEach((k, v) {
        if (v > bestCount) {
          best = k;
          bestCount = v;
        }
      });
      return best;
    }

    return Depth3DCard(
      padding: const EdgeInsets.all(24),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InsightRowWeb(
            icon: Icons.palette_outlined,
            label: 'Most common medium',
            value: topKey(mediumCounts) ?? '—',
          ),
          _InsightRowWeb(
            icon: Icons.person_outline,
            label: 'Most collected artist',
            value: topKey(artistCounts) ?? '—',
          ),
          _InsightRowWeb(
            icon: Icons.auto_graph,
            label: 'Total artworks',
            value: '${paintings.length}',
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }
}

class _InsightRowWeb extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InsightRowWeb({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
