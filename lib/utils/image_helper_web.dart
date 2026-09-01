import 'package:flutter/material.dart';

/// Web fallback — shows a placeholder icon since Image.file isn't available.
Widget nativeImage(
  dynamic file, {
  BoxFit? fit,
  double? width,
  double? height,
  FilterQuality? filterQuality,
  Widget Function(Object, StackTrace, Widget)? errorBuilder,
  bool? gaplessPlayback,
  bool? isAntiAlias,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: const Icon(Icons.image_not_supported_outlined, size: 48),
  );
}
