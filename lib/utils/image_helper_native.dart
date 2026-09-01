import 'package:flutter/widgets.dart';
import 'io_shim.dart' show File;

/// Shows a local image file — only used on native (mobile/desktop).
Widget nativeImage(
  File file, {
  BoxFit? fit,
  double? width,
  double? height,
  FilterQuality? filterQuality,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  bool gaplessPlayback = false,
  bool isAntiAlias = false,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return Image.file(
    file,
    fit: fit,
    width: width,
    height: height,
    filterQuality: filterQuality ?? FilterQuality.low,
    errorBuilder: errorBuilder,
    gaplessPlayback: gaplessPlayback,
    isAntiAlias: isAntiAlias,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
  );
}
