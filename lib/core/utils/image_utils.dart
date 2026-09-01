import 'package:artvault/utils/io_shim.dart';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Image processing helpers: compression, thumbnail generation, perceptual
/// hashing (duplicate detection) and pixel-level analysis for AI features.
abstract final class ImageUtils {
  static const int _hashSize = 9; // 8x8 dHash

  /// Reads, resizes and re-encodes [source] to a smaller JPG. Returns the new
  /// file placed next to the source. Throws if the file is not decodable.
  static Future<File> compress(
    File source, {
    int maxDimension = 2400,
    int quality = 88,
  }) async {
    final bytes = await source.readAsBytes();
    // Heavy decode/resize off the UI thread — 4K photos would jank the gallery scroll.
    final result = await Isolate.run(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final scale = math.min(
        1.0,
        maxDimension / math.max(decoded.width, decoded.height),
      );
      var working = decoded;
      if (scale < 1.0) {
        working = img.copyResize(
          decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      return img.encodeJpg(working, quality: quality);
    });
    if (result == null) return source;
    final out = File(
      '${source.parent.path}${Platform.pathSeparator}'
      '${_baseName(source.path)}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(result, flush: true);
    return out;
  }

  /// Generates a square-ish thumbnail for grids — offloaded to avoid scroll jank.
  static Future<File> thumbnail(File source, {int size = 480}) async {
    final bytes = await source.readAsBytes();
    final encoded = await Isolate.run(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final width = math.min(decoded.width, size);
      final height = (decoded.height * width / decoded.width).round();
      final resized = img.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
      return img.encodeJpg(resized, quality: 80);
    });
    if (encoded == null) return source;
    final out = File(
      '${source.parent.path}${Platform.pathSeparator}'
      '${_baseName(source.path)}_thumb.jpg',
    );
    await out.writeAsBytes(encoded, flush: true);
    return out;
  }

  static String _baseName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// dHash perceptual hash — 64-bit fingerprint used for duplicate detection.
  /// Two images with hash distance < 10 (0-64) are visually very similar.
  static Future<String> perceptualHash(File source) async {
    final bytes = await source.readAsBytes();
    return perceptualHashBytes(bytes);
  }

  static Future<String> perceptualHashBytes(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return '';
    final gray = img.copyResize(
      decoded,
      width: _hashSize,
      height: _hashSize,
      interpolation: img.Interpolation.average,
    );

    final bits = <int>[];
    for (var y = 0; y < _hashSize; y++) {
      for (var x = 0; x < _hashSize - 1; x++) {
        final left = _luma(gray.getPixel(x, y));
        final right = _luma(gray.getPixel(x + 1, y));
        bits.add(left >= right ? 1 : 0);
      }
    }
    return bits.join();
  }

  /// Hamming distance between two dHash strings. Lower = more similar.
  static int hammingDistance(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 64;
    final maxLen = math.max(a.length, b.length);
    var distance = 0;
    for (var i = 0; i < maxLen; i++) {
      if (i >= a.length || i >= b.length || a[i] != b[i]) distance++;
    }
    return distance;
  }

  /// Maps a dHash distance (0-64) to a similarity score (0..1).
  static double similarityFromDistance(int distance) =>
      (1 - distance / 64).clamp(0.0, 1.0);

  static double _luma(img.Pixel p) {
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();
    return 0.299 * r + 0.587 * g + 0.114 * b;
  }

  /// Quantised dominant colors (hex strings). Down-samples the image to a
  /// 64x64 patch and buckets pixels into a coarse RGB grid.
  static List<String> dominantColors(Uint8List bytes, {int count = 5}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];

    final small = img.copyResize(decoded, width: 64, height: 64);
    const bucket = 32; // 8 buckets per channel -> 512 palette
    final buckets = <int>[];
    final totals = <int>[];

    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final r = p.r.toInt() ~/ bucket;
        final g = p.g.toInt() ~/ bucket;
        final b = p.b.toInt() ~/ bucket;
        final key = (r << 12) | (g << 6) | b;
        final idx = buckets.indexOf(key);
        if (idx >= 0) {
          totals[idx]++;
        } else {
          buckets.add(key);
          totals.add(1);
        }
      }
    }

    final order = List<int>.generate(buckets.length, (i) => i)
      ..sort((a, b) => totals[b].compareTo(totals[a]));
    final result = <String>[];
    for (var i = 0; i < math.min(count, order.length); i++) {
      final key = buckets[order[i]];
      final r = ((key >> 12) & 63) * bucket + bucket ~/ 2;
      final g = ((key >> 6) & 63) * bucket + bucket ~/ 2;
      final b = (key & 63) * bucket + bucket ~/ 2;
      final hex =
          '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
      result.add(hex.toUpperCase());
    }
    return result;
  }

  /// Reads a hex color like `#RRGGBB` into a [Color].
  static Color colorFromHex(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final value = int.tryParse(h, radix: 16) ?? 0xFF000000;
    return Color(value);
  }

  /// Extracts perceptual properties used by AI artwork analysis.
  static ({
    double brightness,
    double contrast,
    String orientation,
    double complexity,
  })
  analyzePixelData(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return (
        brightness: 0.5,
        contrast: 0.5,
        orientation: 'Landscape',
        complexity: 0.5,
      );
    }

    final small = img.copyResize(decoded, width: 96, height: 96);
    var sum = 0.0;
    var sumSq = 0.0;
    var edges = 0;
    var samples = 0;

    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final luma = _luma(small.getPixel(x, y)) / 255.0;
        sum += luma;
        sumSq += luma * luma;
        samples++;

        if (x > 0 && y > 0) {
          final left = _luma(small.getPixel(x - 1, y)) / 255.0;
          final top = _luma(small.getPixel(x, y - 1)) / 255.0;
          if ((luma - left).abs() > 0.15 || (luma - top).abs() > 0.15) {
            edges++;
          }
        }
      }
    }

    final mean = sum / samples;
    final variance = (sumSq / samples) - (mean * mean);
    final orientation = decoded.width >= decoded.height
        ? (decoded.width == decoded.height ? 'Square' : 'Landscape')
        : 'Portrait';

    return (
      brightness: mean.clamp(0.0, 1.0),
      contrast: (variance * 5).clamp(0.0, 1.0),
      orientation: orientation,
      complexity: (edges / samples).clamp(0.0, 1.0),
    );
  }
}
