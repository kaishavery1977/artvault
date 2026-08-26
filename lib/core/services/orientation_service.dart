import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_resolution_service.dart';

/// Smart orientation-lock helper that decides which orientations a device
/// should support based on its physical form factor.
///
/// The general rule:
/// - **Phones**: portrait-only by default (most comfortable one-hand use).
///   Landscape is unlocked when the user explicitly enables it.
/// - **Tablets**: both orientations — the wider screen shines in landscape
///   for split-view and side-by-side reading.
/// - **Foldables**: both orientations — the unfolded inner display is wide
///   enough that landscape is natural.
/// - **Desktop mode**: both orientations — the screen is already wide.
///
/// Call [applyForDevice] at startup and whenever the user toggles the
/// "allow landscape" preference in Settings.
class OrientationService {
  OrientationService._();

  static final OrientationService instance = OrientationService._();

  /// Whether the user has explicitly allowed landscape on a phone.
  /// Persisted in settings; defaults to `false`.
  bool _allowLandscapeOnPhone = false;

  bool get allowLandscapeOnPhone => _allowLandscapeOnPhone;

  /// Set the user preference and re-apply immediately.
  Future<void> setAllowLandscapeOnPhone(bool value) async {
    _allowLandscapeOnPhone = value;
    await applyForDevice();
  }

  /// Applies the best orientation policy for the current device.
  ///
  /// Safe to call multiple times (e.g. on rotation or device change).
  /// On phones, landscape is only allowed when the user has opted in.
  /// On tablets, foldables and desktop, both orientations are always allowed.
  Future<void> applyForDevice() async {
    final profile = DeviceResolutionService.instance.current;
    if (profile == null) return;

    List<DeviceOrientation> orientations;

    switch (profile.size) {
      case DeviceSize.compact:
      case DeviceSize.standard:
      case DeviceSize.large:
        // Phones: portrait-only unless the user explicitly allows landscape.
        orientations = _allowLandscapeOnPhone
            ? DeviceOrientation.values
            : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
      case DeviceSize.tablet:
      case DeviceSize.tabletLarge:
      case DeviceSize.desktop:
        // Tablets, foldables, desktop: both orientations always.
        orientations = DeviceOrientation.values;
    }

    await SystemChrome.setPreferredOrientations(orientations);
    debugPrint('OrientationService: locked to $orientations (${profile.size.name})');
  }

  /// Quick predicate: does the current device support landscape by default
  /// (without user opt-in)?
  static bool get deviceSupportsLandscapeByDefault {
    final size = DeviceResolutionService.instance.current?.size;
    return size == DeviceSize.tablet ||
        size == DeviceSize.tabletLarge ||
        size == DeviceSize.desktop;
  }
}
