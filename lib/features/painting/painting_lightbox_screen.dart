import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/painting.dart';

/// Arguments for opening the full-screen artwork viewer.
class LightboxArgs {
  final List<Painting> paintings;
  final int initialIndex;

  const LightboxArgs({required this.paintings, this.initialIndex = 0});
}

/// Full-screen museum-style viewer: swipe between artworks (or an artwork's
/// multiple images), pinch-to-zoom each one, and a caption bar that fades
/// in/out on tap. Wrapped in a soft film vignette for a gallery-lit feel.
class PaintingLightboxScreen extends StatefulWidget {
  final List<Painting> paintings;
  final int initialIndex;

  const PaintingLightboxScreen({
    super.key,
    required this.paintings,
    this.initialIndex = 0,
  });

  @override
  State<PaintingLightboxScreen> createState() => _PaintingLightboxScreenState();
}

class _PaintingLightboxScreenState extends State<PaintingLightboxScreen> {
  late final PageController _controller;
  late int _index;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.paintings.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painting = widget.paintings[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable, pinch-zoomable artwork. The Hero shares the detail
          // screen's tag so the artwork flies into the viewer and back; the
          // tag follows the current page, so popping after swiping to another
          // piece simply falls back to the route fade instead of a wrong
          // flight.
          Hero(
            tag: 'painting-${widget.paintings[_index].id}',
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.paintings.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _index = i);
              },
              itemBuilder: (context, i) {
                final p = widget.paintings[i];
                final imgs = p.images.isEmpty
                    ? <String>[p.coverImagePath]
                    : p.images;
                final urlsP = p.imageUrls.isEmpty
                    ? <String>[p.coverImageUrl]
                    : p.imageUrls;
                return GestureDetector(
                  onTap: () => setState(() => _showChrome = !_showChrome),
                  child: InteractiveViewer(
                    maxScale: 5,
                    minScale: 0.8,
                    // Each artwork settles into place as it arrives — a
                    // quiet museum-frame zoom instead of a hard cut.
                    child: KenBurns(
                      begin: 1.06,
                      duration: const Duration(milliseconds: 1600),
                      child: Center(
                        child: ArtImage(
                          path: imgs.first,
                          url: urlsP.isNotEmpty ? urlsP.first : null,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Museum vignette over the artwork.
          Positioned.fill(child: FilmVignette(strength: 0.38)),
          // Top chrome: close + counter.
          AnimatedOpacity(
            opacity: _showChrome ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.paintings.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom caption bar.
          AnimatedSlide(
            offset: _showChrome ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        painting.title,
                        style: AppTheme.display(
                          context,
                          size: 22,
                        ).copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        painting.artistName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: 6,
                        children: [
                          if (painting.price != null)
                            _CaptionChip(
                              icon: Icons.attach_money,
                              label: Formatters.money(
                                painting.price,
                                currency: painting.currency,
                              ),
                            ),
                          if (painting.dateCreated != null)
                            _CaptionChip(
                              icon: Icons.event,
                              label: painting.dateCreated!,
                            ),
                          _CaptionChip(
                            icon: Icons.brush_outlined,
                            label: painting.medium.isEmpty
                                ? 'Medium unknown'
                                : painting.medium,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: const Text(
                          'Tap anywhere to hide',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CaptionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
