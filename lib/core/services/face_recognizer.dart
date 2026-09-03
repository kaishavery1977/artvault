import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'face_debug_log.dart';

/// On-device face recognition using a MobileFaceNet embedding model.
///
/// The TFLite interpreter runs natively in MainActivity (the tflite_flutter
/// plugin module is incompatible with the current AGP toolchain), exposed
/// here through the `artvault/biometrics` MethodChannel. This service crops
/// the detected face out of a camera frame, runs the model, and compares the
/// resulting 192-dim L2-normalized embedding with cosine similarity — so
/// Face lock matches the enrolled owner instead of accepting any face.
///
/// ## Anti-spoofing
///
/// Beyond embedding similarity the recognizer tracks:
///
/// * **Face quality** — brightness, contrast and size ratio of the crop so
///   enrollments taken in bad lighting or from too far away are rejected.
/// * **Position jitter** — real faces have micro-movements (breathing,
///   pulse, muscle tremor) while printed photos and static video frames are
///   suspiciously still. The [PositionTracker] records the face-centre over
///   a sliding window and flags stillness.
/// * **Adaptive threshold** — consecutive failures tighten the similarity
///   gate so a partially-matching face (e.g. a relative) can't brute-force
///   its way through.
class FaceRecognizer {
  FaceRecognizer._();

  static final FaceRecognizer instance = FaceRecognizer._();

  static const MethodChannel _channel = MethodChannel('artvault/biometrics');

  /// Last error from the native embedding call (empty when the last call
  /// succeeded). Lets the UI show the real cause instead of a silent failure.
  String lastError = '';

  /// Input side of the MobileFaceNet model.
  static const int inputSize = 112;

  /// Base minimum cosine similarity for two embeddings to be treated as the
  /// same person (MobileFaceNet same-person scores are typically 0.65+).
  static const double baseMatchThreshold = 0.60;

  /// Tightened threshold applied after consecutive verify failures so a
  /// partially-matching face can't brute-force through.
  static const double strictMatchThreshold = 0.68;

  /// Number of consecutive failures that triggers the strict threshold.
  static const int failuresForStrictThreshold = 3;

  /// Position tracker for anti-spoofing jitter analysis.
  final PositionTracker positionTracker = PositionTracker();

  /// Consecutive verify failures (reset on success). Drives adaptive
  /// threshold tightening.
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  /// Resets the consecutive failure counter (called on successful verify).
  void resetFailures() {
    _consecutiveFailures = 0;
  }

  /// Increments the consecutive failure counter.
  void recordFailure() {
    _consecutiveFailures++;
  }

  /// The current similarity threshold: tightens after repeated failures.
  double get matchThreshold =>
      _consecutiveFailures >= failuresForStrictThreshold
      ? strictMatchThreshold
      : baseMatchThreshold;

  /// Minimum cosine similarity for two embeddings to be treated as the same
  /// person (MobileFaceNet same-person scores are typically 0.65+).
  static const double matchThresholdStatic = 0.60;

  /// Cosine similarity between two L2-normalized embeddings (0..1).
  double similarity(List<double> a, List<double> b) {
    var dot = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  /// Crops [face] out of an upright RGB frame ([width]x[height], 3 bytes per
  /// pixel), resizes to 112x112, normalizes to [-1, 1] and runs the model.
  /// Returns an empty list if the crop is invalid or inference fails.
  ///
  /// [timeout] bounds the native call: a stalled channel must surface as a
  /// recoverable "no embedding" frame (which the UI reports after a few
  /// misses) rather than leaving the scan frozen on a forever-pending await.
  Future<List<double>> embeddingFromRgb(
    Uint8List rgb,
    int width,
    int height,
    Rect face, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    var left = math.max(0, face.left.floor());
    var top = math.max(0, face.top.floor());
    var right = math.min(width, face.right.ceil());
    var bottom = math.min(height, face.bottom.ceil());
    if (right <= left || bottom <= top) {
      // The box is outside the upright frame — rotation/scale mismatch.
      await FaceDebugLog.instance.log(
        'crop invalid: box=(${face.left.toInt()},${face.top.toInt()},'
        '${face.right.toInt()},${face.bottom.toInt()}) '
        'image=${width}x$height',
      );
      return const [];
    }

    final input = Float32List(inputSize * inputSize * 3);
    for (var y = 0; y < inputSize; y++) {
      final srcY = top + ((bottom - top) * y ~/ inputSize);
      for (var x = 0; x < inputSize; x++) {
        final srcX = left + ((right - left) * x ~/ inputSize);
        final src = (srcY * width + srcX) * 3;
        final dst = (y * inputSize + x) * 3;
        input[dst] = (rgb[src] / 127.5) - 1.0;
        input[dst + 1] = (rgb[src + 1] / 127.5) - 1.0;
        input[dst + 2] = (rgb[src + 2] / 127.5) - 1.0;
      }
    }

    final List<dynamic>? out;
    try {
      out = await _channel
          .invokeMethod<List<dynamic>>('embed', {'input': input.toList()})
          .timeout(timeout);
      lastError = '';
    } on TimeoutException {
      lastError = 'embed channel timed out after ${timeout.inSeconds}s';
      await FaceDebugLog.instance.log('embed channel timed out');
      return const [];
    } catch (e) {
      lastError = 'embed channel error: $e';
      await FaceDebugLog.instance.log('embed channel error: $e');
      return const [];
    }
    if (out == null || out.isEmpty) {
      lastError = 'embed returned null/empty';
      await FaceDebugLog.instance.log('embed returned null/empty');
      return const [];
    }

    final emb = [for (final v in out) (v as num).toDouble()];
    if (emb.length < 16) {
      lastError = 'embed returned ${emb.length} values (expected 192)';
      await FaceDebugLog.instance.log(lastError);
      return const [];
    }

    // The native side already normalizes; normalize again for safety.
    var norm = 0.0;
    for (final v in emb) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm == 0 || !norm.isFinite) {
      lastError = 'embedding norm is $norm (degenerate output)';
      await FaceDebugLog.instance.log(lastError);
      return const [];
    }
    await FaceDebugLog.instance.log(
      'embed ok len=${emb.length} norm=${norm.toStringAsFixed(3)} '
      'first3=${emb.take(3).map((v) => v.toStringAsFixed(3)).join(",")}',
    );
    return [for (final v in emb) v / norm];
  }

  /// Full pipeline: NV21 camera frame -> upright RGB -> crop -> embedding.
  ///
  /// [rotationDeg] must be the SAME value passed to ML Kit's
  /// rotationDegrees (see FaceScanScreen._mlKitRotation). ML Kit rotates the
  /// raw frame clockwise by that amount before detecting, so rotating our
  /// RGB crop clockwise by the same amount keeps the bounding box and the
  /// crop in one shared coordinate space.
  Future<List<double>> embeddingFromNv21(
    Uint8List nv21,
    int width,
    int height,
    int rotationDeg, {
    required Rect face,
  }) async {
    // Convert at half resolution — 4x less work (the debug-mode Dart pixel
    // loop over a full 640x480 frame takes seconds per frame otherwise) and
    // plenty of pixels for a 112x112 crop.
    final (rgb, w2, h2) = nv21ToRgbHalf(nv21, width, height);
    final (upright, uw, uh) = _rotateRgb(rgb, w2, h2, rotationDeg);
    final scaled = Rect.fromLTRB(
      face.left / 2,
      face.top / 2,
      face.right / 2,
      face.bottom / 2,
    );
    return embeddingFromRgb(upright, uw, uh, scaled);
  }

  /// Converts an NV21 frame (Y plane + interleaved V/U) to RGB at HALF
  /// resolution, row-major, 3 bytes per pixel. The source UV plane is only
  /// quarter-resolution anyway, so this loses no chroma detail.
  /// Converts an NV21 frame to RGB at half resolution.
  /// Exposed publicly so [FaceScanScreen] can reuse it for quality scoring.
  (Uint8List, int, int) nv21ToRgbHalf(Uint8List nv21, int width, int height) {
    final w2 = width >> 1;
    final h2 = height >> 1;
    final rgb = Uint8List(w2 * h2 * 3);
    final frameSize = width * height;
    var out = 0;
    for (var oy = 0; oy < h2; oy++) {
      final sy = oy << 1;
      final yRow = sy * width;
      final uvRow = frameSize + oy * width;
      for (var ox = 0; ox < w2; ox++) {
        final sx = ox << 1;
        final yIndex = yRow + sx;
        final uvIndex = uvRow + (sx & ~1);
        final yv = nv21[yIndex];
        final v = nv21[uvIndex] - 128;
        final u = nv21[uvIndex + 1] - 128;

        var r = yv + 1.402 * v;
        var g = yv - 0.344136 * u - 0.714136 * v;
        var b = yv + 1.772 * u;
        r = r < 0 ? 0 : (r > 255 ? 255 : r);
        g = g < 0 ? 0 : (g > 255 ? 255 : g);
        b = b < 0 ? 0 : (b > 255 ? 255 : b);
        rgb[out++] = r.toInt();
        rgb[out++] = g.toInt();
        rgb[out++] = b.toInt();
      }
    }
    return (rgb, w2, h2);
  }

  /// Rotates a row-major RGB buffer clockwise by [deg] (0/90/180/270).
  (Uint8List, int, int) _rotateRgb(Uint8List src, int w, int h, int deg) {
    switch (deg % 360) {
      case 0:
        return (src, w, h);
      case 90:
        final dst = Uint8List(w * h * 3);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final si = (y * w + x) * 3;
            final di = (x * h + (h - 1 - y)) * 3;
            dst[di] = src[si];
            dst[di + 1] = src[si + 1];
            dst[di + 2] = src[si + 2];
          }
        }
        return (dst, h, w);
      case 180:
        final dst = Uint8List(w * h * 3);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final si = (y * w + x) * 3;
            final di = ((h - 1 - y) * w + (w - 1 - x)) * 3;
            dst[di] = src[si];
            dst[di + 1] = src[si + 1];
            dst[di + 2] = src[si + 2];
          }
        }
        return (dst, w, h);
      case 270:
        final dst = Uint8List(w * h * 3);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final si = (y * w + x) * 3;
            final di = ((w - 1 - x) * h + y) * 3;
            dst[di] = src[si];
            dst[di + 1] = src[si + 1];
            dst[di + 2] = src[si + 2];
          }
        }
        return (dst, h, w);
      default:
        return (src, w, h);
    }
  }

  // ---------------------------------------------------------------- Quality --

  /// Evaluates the visual quality of a face crop for enrollment gating.
  ///
  /// Returns a score in [0, 1] where higher is better. The score penalises:
  /// * Too-small faces (far from camera)
  /// * Too-dark or too-bright crops (poor lighting)
  /// * Low contrast (flat lighting / washed-out image)
  ///
  /// Rejects enrollment samples below [minEnrollQuality] so the stored
  /// embedding is taken under decent conditions.
  static const double minEnrollQuality = 0.35;

  double faceQualityScore(Uint8List rgb, int width, int height, Rect face) {
    var left = math.max(0, face.left.floor());
    var top = math.max(0, face.top.floor());
    var right = math.min(width, face.right.ceil());
    var bottom = math.min(height, face.bottom.ceil());
    if (right <= left || bottom <= top) return 0;

    final faceW = (right - left).toDouble();
    final faceH = (bottom - top).toDouble();
    if (faceW < 20 || faceH < 20) return 0;

    // 1. Size ratio — face should fill at least 15% of the frame width.
    final sizeRatio = (faceW / width).clamp(0.0, 1.0);
    final sizeScore = sizeRatio < 0.15 ? sizeRatio / 0.15 : 1.0;

    // 2. Brightness — sample every 4th pixel in the crop.
    var brightnessSum = 0.0;
    var pixelCount = 0;
    final step = 4;
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        final src = (y * width + x) * 3;
        if (src + 2 >= rgb.length) continue;
        final luma =
            (rgb[src] * 0.299 + rgb[src + 1] * 0.587 + rgb[src + 2] * 0.114) /
            255.0;
        brightnessSum += luma;
        pixelCount++;
      }
    }
    if (pixelCount == 0) return 0;
    final brightness = brightnessSum / pixelCount;
    // Penalise too dark (<0.10) or too bright (>0.90).
    double brightnessScore;
    if (brightness < 0.10) {
      brightnessScore = brightness / 0.10;
    } else if (brightness > 0.90) {
      brightnessScore = (1.0 - brightness) / 0.10;
    } else {
      brightnessScore = 1.0;
    }

    // 3. Contrast — standard deviation of luma in the crop.
    var variance = 0.0;
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        final src = (y * width + x) * 3;
        if (src + 2 >= rgb.length) continue;
        final luma =
            (rgb[src] * 0.299 + rgb[src + 1] * 0.587 + rgb[src + 2] * 0.114) /
            255.0;
        final d = luma - brightness;
        variance += d * d;
      }
    }
    final stddev = math.sqrt(variance / pixelCount);
    // Good contrast: stddev > 0.05. Poor: < 0.02.
    final contrastScore = (stddev / 0.05).clamp(0.0, 1.0);

    return (sizeScore * 0.3 + brightnessScore * 0.35 + contrastScore * 0.35)
        .clamp(0.0, 1.0);
  }
}

// ------------------------------------------------------------------------
// Position jitter tracker — anti-spoofing for static images.
// ------------------------------------------------------------------------

/// Tracks face-centre positions over a sliding window to detect the
/// micro-movements of a live face versus the suspicious stillness of a
/// printed photo or a static video frame.
///
/// Real faces drift by 2–8 pixels per second (breathing, pulse, muscle
/// tremor, hand tremor when holding the phone). A photo on a screen or
/// paper produces near-zero variance; a looping video produces periodic
/// variance that falls outside the natural random-walk band.
class PositionTracker {
  /// Rolling buffer of (timestamp, centreX, centreY) samples.
  final List<({DateTime time, double x, double y})> _history = [];

  /// Maximum number of samples retained (≈ 2 seconds at ~15 fps).
  static const int _maxSamples = 30;

  /// Minimum samples needed before jitter can be scored.
  static const int _minSamples = 8;

  /// Window of recent samples used for scoring (≈ 1 second).
  static const int _windowSize = 15;

  /// Threshold: if the standard deviation of face-centre position is below
  /// this (in normalised 0..1 coordinates), the face is likely static.
  static const double _stillnessThreshold = 0.0015;

  /// Records a new face-centre position.
  void addPosition(double x, double y) {
    _history.add((time: DateTime.now(), x: x, y: y));
    if (_history.length > _maxSamples) {
      _history.removeAt(0);
    }
  }

  /// Resets the tracker (e.g. on face lost / scan restart).
  void reset() {
    _history.clear();
  }

  /// Whether enough samples have been collected.
  bool get hasEnoughSamples => _history.length >= _minSamples;

  /// Analyses the most recent samples and returns a liveness confidence
  /// in [0, 1]. Values below 0.5 suggest a static image (photo / screen).
  ///
  /// The score is based on the standard deviation of face-centre position
  /// over the most recent [_windowSize] frames, normalised so that natural
  /// handheld micro-jitter maps to 0.6–1.0 and zero movement maps to ~0.
  double livenessScore() {
    if (_history.length < _minSamples) return 0.5; // neutral until enough data

    final window = _history.length > _windowSize
        ? _history.sublist(_history.length - _windowSize)
        : List<({DateTime time, double x, double y})>.from(_history);

    // Mean position.
    var mx = 0.0;
    var my = 0.0;
    for (final p in window) {
      mx += p.x;
      my += p.y;
    }
    mx /= window.length;
    my /= window.length;

    // Standard deviation of position.
    var varX = 0.0;
    var varY = 0.0;
    for (final p in window) {
      final dx = p.x - mx;
      final dy = p.y - my;
      varX += dx * dx;
      varY += dy * dy;
    }
    final stddevX = math.sqrt(varX / window.length);
    final stddevY = math.sqrt(varY / window.length);
    final stddev = (stddevX + stddevY) / 2;

    // Map stddev to a 0..1 score. 0.001 = very still (suspicious),
    // 0.005+ = clearly live.
    if (stddev < _stillnessThreshold) {
      return (stddev / _stillnessThreshold).clamp(0.0, 0.5);
    }
    return ((stddev - _stillnessThreshold) / 0.005 + 0.5).clamp(0.5, 1.0);
  }

  /// Whether the face appears to be a static image (photo / screen).
  bool get isLikelyStatic => hasEnoughSamples && livenessScore() < 0.3;
}
