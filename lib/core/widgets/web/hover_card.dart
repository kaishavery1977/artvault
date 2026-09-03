import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

/// Hover card popup for artist names on web.
/// Shows a mini profile card when hovering over an artist name.
class ArtistHoverCard extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String? photoUrl;
  final int paintingCount;
  final Widget child;

  const ArtistHoverCard({
    super.key,
    required this.artistId,
    required this.artistName,
    required this.paintingCount,
    required this.child,
    this.photoUrl,
  });

  @override
  State<ArtistHoverCard> createState() => _ArtistHoverCardState();
}

class _ArtistHoverCardState extends State<ArtistHoverCard> {
  OverlayEntry? _overlay;
  bool _isHovering = false;

  void _showOverlay(BuildContext context) {
    if (_overlay != null) return;
    _isHovering = true;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => _HoverCardWidget(
        position: Offset(position.dx, position.dy + size.height + 4),
        artistId: widget.artistId,
        artistName: widget.artistName,
        photoUrl: widget.photoUrl,
        paintingCount: widget.paintingCount,
        onDismiss: _hideOverlay,
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _isHovering = false;
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showOverlay(context),
      onExit: (_) {
        // Small delay so user can move to the card
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isHovering) _hideOverlay();
        });
      },
      child: widget.child,
    );
  }
}

class _HoverCardWidget extends StatefulWidget {
  final Offset position;
  final String artistId;
  final String artistName;
  final String? photoUrl;
  final int paintingCount;
  final VoidCallback onDismiss;

  const _HoverCardWidget({
    required this.position,
    required this.artistId,
    required this.artistName,
    required this.paintingCount,
    required this.onDismiss,
    this.photoUrl,
  });

  @override
  State<_HoverCardWidget> createState() => _HoverCardWidgetState();
}

class _HoverCardWidgetState extends State<_HoverCardWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child:
          MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) {
                  setState(() => _hovered = false);
                  widget.onDismiss();
                },
                child: GestureDetector(
                  onTap: () {
                    widget.onDismiss();
                    context.push('/artist/${widget.artistId}');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1F30) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _hovered
                            ? AppColors.accent.withValues(alpha: 0.3)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08)),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        if (_hovered)
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            blurRadius: 12,
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.violet500.withValues(alpha: 0.3),
                                AppColors.cyan400.withValues(alpha: 0.3),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.artistName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.artistName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.paintingCount} painting${widget.paintingCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 150.ms)
              .slideY(
                begin: -0.05,
                duration: 150.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}
