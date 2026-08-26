import 'package:flutter/material.dart';

import '../services/device_resolution_service.dart';

/// InheritedWidget that injects the resolved [DeviceProfile] into the
/// widget tree. Every descendant can read the profile via
/// `AdaptiveLayout.of(context)` or the [BuildContext] extensions below.
///
/// Wraps [MaterialApp] in [main.dart] so it's available everywhere.
class AdaptiveLayout extends InheritedWidget {
  final DeviceProfile profile;

  const AdaptiveLayout({
    super.key,
    required this.profile,
    required super.child,
  });

  static DeviceProfile of(BuildContext context) {
    final layout = context.dependOnInheritedWidgetOfExactType<AdaptiveLayout>();
    assert(layout != null, 'No AdaptiveLayout found in context');
    return layout!.profile;
  }

  static DeviceProfile? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdaptiveLayout>()?.profile;
  }

  @override
  bool updateShouldNotify(AdaptiveLayout oldWidget) {
    return profile.scaleFactor != oldWidget.profile.scaleFactor ||
        profile.size != oldWidget.profile.size;
  }
}

// ---------------------------------------------------------------------------
// Context extensions — the primary API consumed by screen widgets.
// ---------------------------------------------------------------------------

extension AdaptiveContext on BuildContext {
  /// Full device profile captured at launch.
  DeviceProfile get deviceProfile => AdaptiveLayout.of(this);

  /// Multiplicative scale factor for padding, spacing, radii, icon sizes.
  /// Standard phone ≈ 1.0, compact phone ≈ 0.85–0.95, tablet ≈ 1.2–1.4.
  double get scale => deviceProfile.scaleFactor;

  /// Dampened scale for font sizes (less aggressive than padding scale).
  double get fontScale => deviceProfile.fontScale;

  /// Current device size bucket.
  DeviceSize get deviceSize => deviceProfile.size;

  // ---- Convenience predicates -----------------------------------------------

  bool get isCompactPhone => deviceSize == DeviceSize.compact;
  bool get isStandardPhone => deviceSize == DeviceSize.standard;
  bool get isLargePhone => deviceSize == DeviceSize.large;
  bool get isTablet =>
      deviceSize == DeviceSize.tablet || deviceSize == DeviceSize.tabletLarge;
  bool get isDesktop => deviceSize == DeviceSize.desktop;
  bool get isPhone =>
      deviceSize == DeviceSize.compact ||
      deviceSize == DeviceSize.standard ||
      deviceSize == DeviceSize.large;

  // ---- Orientation helpers -------------------------------------------------

  /// True when the screen is wider than it is tall.
  bool get isLandscape => deviceProfile.isLandscape;

  /// True when the screen is taller than it is wide.
  bool get isPortrait => !deviceProfile.isLandscape;

  // ---- Scaled spacing helpers -----------------------------------------------

  /// Scale a base spacing value by the device scale factor.
  double scaled(double base) => base * scale;

  /// Scale a base font size (dampened).
  double scaledFont(double base) => base * fontScale;

  /// Scale an edge inset uniformly.
  EdgeInsets scaledPadding(EdgeInsets base) => base * scale;

  /// Scale a border radius.
  double scaledRadius(double base) => base * scale;

  /// Scale an icon size.
  double scaledIcon(double base) => base * scale;
}
