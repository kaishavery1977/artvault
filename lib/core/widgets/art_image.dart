import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Renders a painting image from either local disk or the network.
///
/// - Local files render instantly from disk.
/// - Remote URLs stream through the disk cache for repeat loads.
/// - Broken images fall back to an elegant placeholder.
class ArtImage extends StatelessWidget {
  final String? path;
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Widget? placeholder;

  const ArtImage({
    super.key,
    this.path,
    this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
  });

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.10),
            scheme.primary.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: placeholder ??
          Center(
            child: Icon(
              Icons.brush_outlined,
              size: 34,
              color: scheme.primary.withValues(alpha: 0.35),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Avoid File.existsSync() in build() — it's a blocking disk I/O call
    // that causes jank when many ArtImage widgets rebuild (e.g. gallery grid
    // scroll). Instead, attempt to load the file and let errorBuilder handle
    // missing files gracefully.
    final hasPath = path != null && path!.isNotEmpty;
    final hasUrl = url != null && url!.isNotEmpty;

    Widget? child;
    if (hasPath) {
      child = Image.file(
        File(path!),
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.low,
        // errorBuilder handles non-existent files, permission errors, etc.
        errorBuilder: (_, _, _) =>
            hasUrl ? _networkImage(context) : _fallback(context),
      );
    } else if (hasUrl) {
      child = _networkImage(context);
    } else {
      child = _fallback(context);
    }

    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _networkImage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => _fallback(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }
}

/// Simple spacer used in scrollviews to respect safe areas.
class BottomSpacer extends StatelessWidget {
  const BottomSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(height: bottom + AppSpacing.lg);
  }
}
