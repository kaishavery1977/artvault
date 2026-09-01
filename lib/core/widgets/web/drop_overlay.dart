import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';

/// Drag-and-drop file upload overlay for web.
/// Wraps the app and shows a visual overlay when files are dragged over.
/// On mobile, this is a no-op wrapper.
///
/// NOTE: For full browser drag-and-drop integration, add `package:web` to
/// pubspec.yaml and wire up DOM event listeners via conditional imports.
/// This version provides the visual overlay and structure.
class DropOverlay extends StatefulWidget {
  final Widget child;
  const DropOverlay({super.key, required this.child});

  @override
  State<DropOverlay> createState() => _DropOverlayState();
}

class _DropOverlayState extends State<DropOverlay> {
  bool _isDragging = false;

  /// Call this to simulate a drag event (e.g., from a web-specific listener).
  void showOverlay() => setState(() => _isDragging = true);
  void hideOverlay() => setState(() => _isDragging = false);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isDragging)
          Positioned.fill(
            child: Container(
              color: AppColors.accent.withValues(alpha: 0.15),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Drop to upload',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Release to add to your collection',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.accent.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(
                  begin: const Offset(0.95, 0.95),
                  duration: 200.ms,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ).animate().fadeIn(duration: 150.ms),
          ),
      ],
    );
  }
}
