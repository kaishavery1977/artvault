import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device size categories based on physical screen resolution.
enum DeviceSize {
  /// Small phones (< 360dp width): iPhone SE, Galaxy Mini, etc.
  compact,

  /// Standard phones (360–411dp): most Android phones, iPhone 13/14/15
  standard,

  /// Large phones (412–480dp): Galaxy S series Ultra, iPhone Pro Max
  large,

  /// Small tablets (481–600dp): iPad Mini, foldables unfolded
  tablet,

  /// Large tablets (601–900dp): iPad Air/Pro, Android tablets
  tabletLarge,

  /// Desktop / ultra-wide (> 900dp): desktop mode, foldables with big screens
  desktop,
}

/// Persisted resolution profile captured at install and refreshed on every
/// launch. Used by [AdaptiveLayout] to scale the entire UI proportionally.
class DeviceProfile {
  /// Physical width in logical pixels.
  final double widthDp;

  /// Physical height in logical pixels.
  final double heightDp;

  /// Device pixel ratio (physical pixels per logical pixel).
  final double devicePixelRatio;

  /// Physical width in actual pixels.
  final double widthPx;

  /// Physical height in actual pixels.
  final double heightPx;

  /// Shortest side in logical pixels (portrait or landscape).
  final double shortestSide;

  /// Categorised size bucket.
  final DeviceSize size;

  /// Scaling multiplier relative to the "standard" phone baseline (393dp).
  /// Values < 1.0 shrink everything; > 1.0 enlarge.
  final double scaleFactor;

  /// Font scaling multiplier derived from scale factor but dampened so text
  /// doesn't grow/shrink as aggressively as padding.
  final double fontScale;

  /// True if the device has a very high pixel density (>= 3.0).
  final bool isHighDensity;

  /// True when the screen is wider than it is tall (landscape).
  final bool isLandscape;

  /// Timestamp when this profile was captured.
  final DateTime capturedAt;

  const DeviceProfile({
    required this.widthDp,
    required this.heightDp,
    required this.devicePixelRatio,
    required this.widthPx,
    required this.heightPx,
    required this.shortestSide,
    required this.size,
    required this.scaleFactor,
    required this.fontScale,
    required this.isHighDensity,
    required this.isLandscape,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
    'widthDp': widthDp,
    'heightDp': heightDp,
    'devicePixelRatio': devicePixelRatio,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'shortestSide': shortestSide,
    'size': size.name,
    'scaleFactor': scaleFactor,
    'fontScale': fontScale,
    'isHighDensity': isHighDensity,
    'isLandscape': isLandscape,
    'capturedAt': capturedAt.toIso8601String(),
  };

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => DeviceProfile(
    widthDp: (json['widthDp'] as num).toDouble(),
    heightDp: (json['heightDp'] as num).toDouble(),
    devicePixelRatio: (json['devicePixelRatio'] as num).toDouble(),
    widthPx: (json['widthPx'] as num).toDouble(),
    heightPx: (json['heightPx'] as num).toDouble(),
    shortestSide: (json['shortestSide'] as num).toDouble(),
    size: DeviceSize.values.firstWhere(
      (s) => s.name == json['size'],
      orElse: () => DeviceSize.standard,
    ),
    scaleFactor: (json['scaleFactor'] as num).toDouble(),
    fontScale: (json['fontScale'] as num).toDouble(),
    isHighDensity: json['isHighDensity'] as bool? ?? false,
    isLandscape: json['isLandscape'] as bool? ?? false,
    capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// Build a fresh profile from the current [MediaQueryData].
  factory DeviceProfile.fromMediaQuery(MediaQueryData mq) {
    final w = mq.size.width;
    final h = mq.size.height;
    final dpr = mq.devicePixelRatio;
    final shortest = mq.size.shortestSide;

    final size = _categorise(shortest);
    final scaleFactor = _computeScaleFactor(shortest);
    final fontScale = _computeFontScale(scaleFactor);

    return DeviceProfile(
      widthDp: w,
      heightDp: h,
      devicePixelRatio: dpr,
      widthPx: w * dpr,
      heightPx: h * dpr,
      shortestSide: shortest,
      size: size,
      scaleFactor: scaleFactor,
      fontScale: fontScale,
      isHighDensity: dpr >= 3.0,
      isLandscape: w > h,
      capturedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Categorisation helpers
  // ---------------------------------------------------------------------------

  static DeviceSize _categorise(double shortestSide) {
    if (shortestSide < 320) return DeviceSize.compact;
    if (shortestSide < 390) return DeviceSize.standard;
    if (shortestSide < 480) return DeviceSize.large;
    if (shortestSide < 600) return DeviceSize.tablet;
    if (shortestSide < 900) return DeviceSize.tabletLarge;
    return DeviceSize.desktop;
  }

  /// Scale factor relative to a 393dp "standard" phone baseline (iPhone 14
  /// logical width). Compact phones shrink, tablets grow — but the curve is
  /// dampened so small phones don't collapse and tablets don't balloon.
  static double _computeScaleFactor(double shortestSide) {
    const baseline = 393.0;
    final raw = shortestSide / baseline;
    // Dampen with a square-root curve so the range stays between ~0.85 and ~1.6
    final dampened = raw.clamp(0.80, 2.0);
    return dampened.clamp(0.85, 1.6);
  }

  static double _computeFontScale(double scale) {
    // Fonts scale more conservatively than padding/spacing so readability
    // doesn't suffer on small screens or balloon on tablets.
    return 0.5 + (scale * 0.5); // range ~0.92 – 1.3
  }

  @override
  String toString() =>
      'DeviceProfile(${size.name}, ${widthDp.round()}x${heightDp.round()}dp, '
      'dpr=$devicePixelRatio, scale=${scaleFactor.toStringAsFixed(2)}, '
      '${isLandscape ? 'landscape' : 'portrait'})';
}

/// Background resolution detection service.
///
/// Captures the device profile:
/// 1. **On install** — first launch stores a profile in Hive.
/// 2. **On every launch** — refreshes the profile (orientation, display
///    settings, or device swap may have changed things).
///
/// Widgets read the profile through the inherited [AdaptiveLayout] rather
/// than calling this service directly.
class DeviceResolutionService {
  DeviceResolutionService._();

  static final DeviceResolutionService instance = DeviceResolutionService._();

  static const String _boxName = 'device_resolution';
  static const String _key = 'profile';

  DeviceProfile? _current;

  /// The most recently captured profile. Null only before the first call
  /// to [detect] — which happens in [main] before runApp.
  DeviceProfile? get current => _current;

  /// Detects the current device resolution and persists it.
  ///
  /// Safe to call multiple times; the in-memory profile and Hive are
  /// updated each time so orientation changes are captured.
  Future<DeviceProfile> detect(MediaQueryData mq) async {
    final profile = DeviceProfile.fromMediaQuery(mq);
    _current = profile;

    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      await box.put(_key, profile.toJson());
    } catch (_) {
      // Hive may not be ready during early boot — non-fatal; we keep the
      // in-memory profile and try again next launch.
    }

    debugPrint('DeviceResolutionService: $profile');
    return profile;
  }

  /// Loads the previously persisted profile (from install) without
  /// overwriting it. Useful if we want to compare "old vs new" in the
  /// future. Returns null on first install or if Hive is unavailable.
  Future<DeviceProfile?> loadPersisted() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      final json = box.get(_key);
      if (json == null) return null;
      return DeviceProfile.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (_) {
      return null;
    }
  }
}
