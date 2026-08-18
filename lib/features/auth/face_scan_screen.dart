import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/face_debug_log.dart';
import '../../core/services/face_recognizer.dart';
import '../../core/widgets/success_overlay.dart';

/// What the face scan is being used for.
enum FaceScanMode {
  /// Capture the owner's face and return their embedding (enroll).
  enroll,

  /// Check the camera feed against an already-enrolled embedding (unlock).
  verify,
}

/// Camera-based face scan for "Face lock".
///
/// Android OEMs like vivo do not expose face identity matching to apps (their
/// Face Wake is system-only), so the app runs its own recognition: the front
/// camera streams frames through ML Kit for face detection, then a
/// MobileFaceNet embedding model decides whether the face matches the
/// enrolled owner — not merely that a face is present.
///
/// - [FaceScanMode.enroll] pops with the averaged `List<double>` embedding
///   (or `null` if cancelled/failed).
/// - [FaceScanMode.verify] pops with `true` when the face matches the
///   enrolled embedding, `false` otherwise.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({
    super.key,
    this.mode = FaceScanMode.verify,
    this.enrolledEmbedding,
  });

  final FaceScanMode mode;
  final List<double>? enrolledEmbedding;

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
    ),
  );

  bool _ready = false;
  bool _processing = false;
  bool _done = false;

  /// Frames with a detected face before sampling starts. Decays (rather
  /// than hard-resets) on a missed frame so detection flicker can't stall
  /// enrollment indefinitely.
  int _hits = 0;

  /// Verify mode: consecutive matching frames needed to unlock.
  int _matchHits = 0;

  /// Enroll mode: collected embeddings (averaged at the end).
  final List<List<double>> _samples = [];

  String _status = 'Starting camera…';

  DateTime? _streamStartedAt;

  /// When the face was last seen (null while a face is present). Used to
  /// distinguish brief detection flicker from a genuinely lost face.
  DateTime? _noFaceSince;

  int _frameCount = 0;
  int _frameErrors = 0;
  int _embedFails = 0;
  bool _warnedNoFace = false;

  /// Verify mode: consecutive non-matching frames (drives the failure hint).
  int _failStreak = 0;

  /// True once enrollment/verification finished, showing the success overlay
  /// before the screen pops with the result.
  bool _successShown = false;

  /// Latest detected face (ML Kit upright-space box + raw frame dims) for the
  /// live on-screen bounding-box overlay. Kept in a [ValueNotifier] so the
  /// per-frame detection loop only repaints the overlay, never the whole
  /// screen.
  final ValueNotifier<({Rect box, int width, int height})?> _faceBox =
      ValueNotifier(null);

  /// True while the user-cancelled fade-out is playing before popping.
  bool _cancelled = false;

  /// Optional secondary line shown under the success message.
  String? _successSubtitle;

  // Animations: sweep line, breathing frame, success reveal.
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  /// Cancel fade-out.
  late final AnimationController _cancelAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  static const int _steadyFrames = 2;
  static const int _enrollFrames = 6;
  static const int _matchFrames = 6;

  @override
  void initState() {
    super.initState();
    _scan.repeat();
    _pulse.repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    // If the camera pipeline doesn't come up in time, surface it instead of
    // spinning on "Starting camera…" forever: a wedged camera HAL or a slow
    // permission dialog must never look like an infinite loading state. The
    // guard is cancelled on every exit path (success, early return, error).
    final initGuard = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready && !_done) {
        setState(() {
          _status = 'Camera is taking too long — go back and try another '
              'unlock method';
        });
      }
    });
    void cancelGuard() => initGuard.cancel();

    try {
      final granted = await Permission.camera.request().isGranted;
      if (!granted) {
        cancelGuard();
        if (mounted) {
          setState(
            () => _status = 'Camera permission is required for face unlock',
          );
        }
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        cancelGuard();
        if (mounted) setState(() => _status = 'No camera found on this device');
        return;
      }
      final camera = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      await FaceDebugLog.instance.log(
        'camera: lens=${camera.lensDirection.name} '
        'sensor=${camera.sensorOrientation} '
        'mlkit=${_mlKitRotationFor(camera)}',
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      _controller = controller;
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      _streamStartedAt = DateTime.now();
      cancelGuard();
      if (mounted) {
        setState(() {
          _ready = true;
          _status = widget.mode == FaceScanMode.enroll
              ? 'Hold still — capturing your face…'
              : 'Look at the camera';
        });
      }
    } catch (e) {
      cancelGuard();
      if (mounted) setState(() => _status = 'Camera error: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_done || _processing || !mounted) return;
    _processing = true;
    _frameCount++;
    try {
      // If no sample has been captured after a while, say what to fix
      // instead of spinning on "Hold still…" forever.
      if (_samples.isEmpty &&
          _streamStartedAt != null &&
          !_warnedNoFace &&
          DateTime.now().difference(_streamStartedAt!) >
              const Duration(seconds: 15) &&
          mounted) {
        _warnedNoFace = true;
        setState(() {
          _status =
              'No face detected — keep your face inside the oval, in good light';
        });
      }

      final faces = await _detector.processImage(_toInputImage(image));
      if (_done || !mounted) return;

      if (faces.isEmpty) {
        // Brief flicker must never wipe progress. Decay the hit counter one
        // frame at a time; only a sustained absence (5s) resets capture, and
        // even then samples stay until the next face actually moves away.
        _hits = _hits > 0 ? _hits - 1 : 0;
        _faceBox.value = null;
        _noFaceSince ??= DateTime.now();
        final awayFor = DateTime.now().difference(_noFaceSince!);
        if (awayFor > const Duration(seconds: 5)) {
          _matchHits = 0;
          _failStreak = 0;
          _samples.clear();
        } else if (_hits == 0) {
          // Flicker: decay match momentum, keep already-captured samples.
          _matchHits = _matchHits > 0 ? _matchHits - 1 : 0;
          _failStreak = 0;
        }
        // Throttled log so a stuck pipeline is diagnosable via face_debug.log.
        if (_frameCount % 30 == 0) {
          await FaceDebugLog.instance.log(
            'no face detected (frame $_frameCount, away=${awayFor.inSeconds}s)',
          );
        }
        return;
      }
      _noFaceSince = null;

      _warnedNoFace = false;
      _frameErrors = 0;

      // Use the largest face in the frame.
      final face = faces.reduce(
        (a, b) =>
            a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b,
      );

      // Drive the live bounding-box overlay. The box is in ML Kit's upright
      // (post-rotation) coordinate space; the painter maps it to the screen
      // using the same rotation + mirror assumptions as the preview.
      _faceBox.value = (
        box: face.boundingBox,
        width: image.width,
        height: image.height,
      );

      if (_frameCount == 1) {
        await FaceDebugLog.instance.log(
          'overlay: rot=${_mlKitRotation()} upright='
          '${_mlKitRotation() % 180 == 0 ? image.width : image.height}'
          'x${_mlKitRotation() % 180 == 0 ? image.height : image.width} '
          'front=${_controller?.description.lensDirection == CameraLensDirection.front}',
        );
      }

      await FaceDebugLog.instance.log(
        'frame w=${image.width} h=${image.height} '
        'sensor=${_controller?.description.sensorOrientation ?? 0} '
        'mlkit=${_mlKitRotation()} faces=${faces.length} '
        'box=(${face.boundingBox.left.toInt()},${face.boundingBox.top.toInt()},'
        '${face.boundingBox.right.toInt()},${face.boundingBox.bottom.toInt()})',
      );

      _hits++;
      if (_hits < _steadyFrames) return;

      final controller = _controller;
      if (controller == null) return;
      final emb = await FaceRecognizer.instance.embeddingFromNv21(
        _nv21Bytes(image),
        image.width,
        image.height,
        _mlKitRotation(),
        face: face.boundingBox,
      );
      if (_done || !mounted) return;
      if (emb.isEmpty) {
        _embedFails++;
        await FaceDebugLog.instance.log(
          'emb empty: ${FaceRecognizer.instance.lastError}',
        );
        // Surface the real cause after a few failures instead of silently
        // staying stuck on "Hold still…".
        if (_embedFails == 3 && mounted) {
          setState(() {
            _status = 'Face scan error: ${FaceRecognizer.instance.lastError}';
          });
        }
        return;
      }
      _embedFails = 0;

      if (widget.mode == FaceScanMode.enroll) {
        _samples.add(emb);
        HapticFeedback.lightImpact();
        debugPrint('face_enroll sample ${_samples.length}/$_enrollFrames');
        await FaceDebugLog.instance.log(
          'enroll sample ${_samples.length}/$_enrollFrames',
        );
        if (mounted) {
          setState(() {
            _status = 'Capturing ${_samples.length}/$_enrollFrames…';
          });
        }
        if (_samples.length >= _enrollFrames) {
          final avg = _average(_samples);
          await FaceDebugLog.instance.log(
            'enroll complete, popping ${avg.length} dims',
          );
          await _finishWithSuccess(
            avg,
            message: 'Face registered successfully!',
            subtitle: 'Face lock is now active',
          );
        }
      } else {
        final reference = widget.enrolledEmbedding;
        if (reference == null || reference.isEmpty) {
          // Nothing to match against — treat as failure.
          await _finishWithSuccess(
            false,
            message: 'No enrolled face',
            subtitle: 'Set up Face lock first',
          );
          return;
        }
        final sim = FaceRecognizer.instance.similarity(emb, reference);
        await FaceDebugLog.instance.log(
          'verify sim=${sim.toStringAsFixed(3)} hits=$_matchHits',
        );
        if (sim >= FaceRecognizer.matchThreshold) {
          _matchHits++;
          HapticFeedback.lightImpact();
          _failStreak = 0;
          if (mounted) {
            setState(() {
              _status = 'Matching… $_matchHits/$_matchFrames';
            });
          }
          if (_matchHits >= _matchFrames) {
            await FaceDebugLog.instance.log('verify UNLOCKED');
            await _finishWithSuccess(
              true,
              message: 'Face recognized — unlocking…',
            );
          }
        } else {
          // Decay rather than reset: one stray non-matching frame must not
          // erase 5 good matches.
          _matchHits = _matchHits > 0 ? _matchHits - 1 : 0;
          _failStreak++;
          if (_failStreak == 8 && mounted) {
            await FaceDebugLog.instance.log('verify mismatch streak=8');
            setState(() {
              _status = 'Face not recognized — hold steady and try again';
            });
          } else if (_failStreak == 16 && mounted) {
            setState(() {
              _status = 'Still not matching — check the light and angle';
            });
          }
        }
      }
    } catch (e) {
      // Skip the frame — a transient decode error must not fail the scan —
      // but record it so a persistent failure is visible in the log and on
      // screen instead of looking like an infinite "Hold still".
      _frameErrors++;
      await FaceDebugLog.instance.log('frame error: $e');
      if (_frameErrors == 5 && mounted) {
        setState(() {
          _status = 'Camera processing error: $e';
        });
      }
    } finally {
      _processing = false;
    }
  }

  /// Stops the stream, plays the success animation and pops with [result]
  /// after the confirmation has been shown.
  /// Stops the scan, plays a brief "Scan cancelled" fade-out and pops with
  /// the failure result instead of closing instantly.
  Future<void> _cancel() async {
    if (_done || _cancelled) return;
    _cancelled = true;
    _done = true;
    HapticFeedback.mediumImpact();
    _scan.stop();
    _pulse.stop();
    await _controller?.stopImageStream();
    await FaceDebugLog.instance.log('scan cancelled by user');
    if (!mounted) return;
    setState(() {});
    _cancelAnim.forward();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      Navigator.of(
        context,
      ).pop(widget.mode == FaceScanMode.enroll ? null : false);
    }
  }

  Future<void> _finishWithSuccess(
    dynamic result, {
    required String message,
    String? subtitle,
  }) async {
    if (_done) return;
    _done = true;
    HapticFeedback.heavyImpact();
    await _controller?.stopImageStream();
    if (!mounted) return;
    setState(() {
      _successShown = true;
      _successSubtitle = subtitle;
      _status = message;
    });
    _success.forward();
    await FaceDebugLog.instance.log('scan complete: $message');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop(result);
  }

  List<double> _average(List<List<double>> samples) {
    if (samples.isEmpty) return const [];
    final n = samples.first.length;
    final sums = List<double>.filled(n, 0);
    for (final s in samples) {
      for (var i = 0; i < n && i < s.length; i++) {
        sums[i] += s[i];
      }
    }
    // L2-normalize the averaged vector. (Bug fixed: divide by sqrt of the
    // sum of squares, not the sum itself.)
    var norm = 0.0;
    for (var i = 0; i < n; i++) {
      sums[i] /= samples.length;
      norm += sums[i] * sums[i];
    }
    norm = math.sqrt(norm);
    final inv = norm == 0 ? 1.0 : 1.0 / norm;
    return [for (var i = 0; i < n; i++) sums[i] * inv];
  }

  Uint8List _nv21Bytes(CameraImage image) {
    final Uint8List bytes = Uint8List(
      image.planes.fold<int>(0, (n, p) => n + p.bytes.length),
    );
    var offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }

  /// ML Kit's rotationDegrees, per the official google_mlkit sample formula:
  ///   front camera: (sensorOrientation + deviceRotation) % 360
  ///   back camera:  (sensorOrientation - deviceRotation + 360) % 360
  /// where deviceRotation is the display rotation (0 = portrait, 90 =
  /// landscape; the up/down/left/right variant only matters in landscape and
  /// is approximated as 90). The SAME value is used to rotate the RGB crop in
  /// FaceRecognizer, so the ML Kit bounding box and our crop share one
  /// coordinate space.
  int _mlKitRotation() {
    final c = _controller;
    if (c == null) return 0;
    return _mlKitRotationFor(c.description);
  }

  int _mlKitRotationFor(CameraDescription camera) {
    final isFront = camera.lensDirection == CameraLensDirection.front;
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final device = portrait ? 0 : 90;
    return isFront
        ? (camera.sensorOrientation + device) % 360
        : (camera.sensorOrientation - device + 360) % 360;
  }

  /// Maps an ML Kit bounding box (upright image space, same rotation as
  /// [_toInputImage]) onto the full-screen preview widget.
  ///
  /// The CameraPreview fills the whole screen (AspectRatio collapses under
  /// tight constraints), so a simple axis-aligned scale maps upright-space to
  /// widget space. CameraX mirrors the front-camera preview by default
  /// (MIRROR_MODE_ON_FRONT_ONLY), so for the front lens the box is flipped
  /// horizontally to land on the face the user sees.
  Rect? _screenRectFor(
    ({Rect box, int width, int height}) data,
    Size size,
  ) {
    final c = _controller;
    if (c == null || size.isEmpty) return null;
    final rot = _mlKitRotation();
    final isFront = c.description.lensDirection == CameraLensDirection.front;
    final uprightW =
        (rot % 180 == 0) ? data.width.toDouble() : data.height.toDouble();
    final uprightH =
        (rot % 180 == 0) ? data.height.toDouble() : data.width.toDouble();
    if (uprightW <= 0 || uprightH <= 0) return null;
    final sx = size.width / uprightW;
    final sy = size.height / uprightH;
    final left = isFront ? (uprightW - data.box.right) * sx : data.box.left * sx;
    final right = isFront ? (uprightW - data.box.left) * sx : data.box.right * sx;
    return Rect.fromLTRB(left, data.box.top * sy, right, data.box.bottom * sy);
  }

  InputImage _toInputImage(CameraImage image) {
    final rotation =
        InputImageRotationValue.fromRawValue(_mlKitRotation()) ??
        InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: _nv21Bytes(image),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _done = true;
    _faceBox.dispose();
    _scan.dispose();
    _pulse.dispose();
    _success.dispose();
    _cancelAnim.dispose();
    // Only stop the image stream when one is actually active — the camera
    // plugin throws if stopImageStream is called while nothing is streaming
    // (e.g. the lock gate tears the screen down before the stream starts).
    final cam = _controller;
    if (cam != null && cam.value.isStreamingImages) {
      cam.stopImageStream();
    }
    cam?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnroll = widget.mode == FaceScanMode.enroll;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_ready && _controller != null)
              Positioned.fill(child: CameraPreview(_controller!)),
            // Soft vignette so the scan frame reads clearly on bright scenes.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Live ML Kit face bounding box — a debug alignment aid so the
            // detected box can be compared against the scan oval.
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return ValueListenableBuilder<
                      ({Rect box, int width, int height})?
                    >(
                      valueListenable: _faceBox,
                      builder: (context, data, _) {
                        if (data == null) return const SizedBox.shrink();
                        final rect = _screenRectFor(data, size);
                        if (rect == null) return const SizedBox.shrink();
                        return CustomPaint(
                          size: size,
                          painter: _FaceBoxPainter(rect),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: _done ? null : _cancel,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    isEnroll
                        ? 'Set up Face lock — look at the camera'
                        : 'Face unlock — look at the camera',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.25),
            ),
            // Scan frame: pulsing oval, sweeping scan line, progress ring.
            Center(child: _buildScanFrame(isEnroll)),
            // Bottom status + progress indicator.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _status,
                      key: ValueKey(_status),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    if (_ready) ...[
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Success overlay with confirmation.
            if (_successShown)
              SuccessCheckOverlay(
                animation: _success,
                message: _status,
                subtitle: _successSubtitle,
              ),
            // User-cancelled fade-out before popping.
            if (_cancelled)
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _cancelAnim,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              size: 52,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan cancelled',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Returning to the lock screen',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The pulsing oval with the sweeping scan line and enroll progress ring.
  Widget _buildScanFrame(bool isEnroll) {
    final ringProgress = _successShown
        ? 1.0
        : (_samples.length / _enrollFrames).clamp(0.0, 1.0);

    return SizedBox(
      width: 272,
      height: 272,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isEnroll)
            SizedBox(
              width: 268,
              height: 268,
              child: CircularProgressIndicator(
                value: ringProgress,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: Colors.greenAccent,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          AnimatedBuilder(
            animation: Listenable.merge([_scan, _pulse]),
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulse.value);
              final lineY = 14 + _scan.value * (240 - 28);
              return Transform.scale(
                scale: 1 + 0.03 * t,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45 + 0.4 * t),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.10 * t),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        // Sweeping scan line.
                        Positioned(
                          top: lineY - 1.5,
                          left: 0,
                          right: 0,
                          height: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.cyanAccent.withValues(alpha: 0.95),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withValues(
                                    alpha: 0.75,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Sample counter — pops in on every new capture.
                        if (_samples.isNotEmpty)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_samples.length}/$_enrollFrames',
                                  key: ValueKey(_samples.length),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ).animate().scale(
                                  begin: const Offset(1.35, 1.35),
                                  curve: Curves.easeOutBack,
                                  duration: 260.ms,
                                ),
                                Text(
                                  'captured',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Draws the live face-detection box as bright corner brackets with a soft
/// fill, so alignment is visible against the scan oval without obscuring it.
class _FaceBoxPainter extends CustomPainter {
  final Rect rect;

  const _FaceBoxPainter(this.rect);

  static const double _corner = 22;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      rect,
      Paint()..color = Colors.greenAccent.withValues(alpha: 0.10),
    );
    final stroke = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(rect.left, rect.top + _corner)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + _corner, rect.top)
      ..moveTo(rect.right - _corner, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + _corner)
      ..moveTo(rect.right, rect.bottom - _corner)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - _corner, rect.bottom)
      ..moveTo(rect.left + _corner, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - _corner);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
