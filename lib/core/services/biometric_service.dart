import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Result of a face-unlock attempt.
///
/// [needsCameraScan] means the platform has no usable system face biometric
/// (common on Android OEMs like vivo), so the caller must run the in-app
/// camera face scan instead.
enum FaceAuthResult { success, failed, needsCameraScan }

/// Which unlock methods the device actually supports right now.
class BiometricAvailability {
  /// Any biometric (fingerprint or face) usable for unlock.
  final bool any;

  /// A fingerprint-capable (strong) biometric is enrolled.
  final bool fingerprint;

  /// A face-unlock path is available (front camera on Android, Face ID on
  /// iOS).
  final bool face;

  const BiometricAvailability({
    required this.any,
    required this.fingerprint,
    required this.face,
  });
}

/// Wraps platform biometric authentication (fingerprint / Face ID).
class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Native channel (MainActivity) that restricts the prompt to one biometric
  /// class: `strong` = fingerprint (Class 3), `weak` = face (Class 2).
  static const MethodChannel _native = MethodChannel('artvault/biometrics');

  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final hasHardware = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      return canCheck && hasHardware && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Detailed status for debugging.
  Future<String> get status async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final hasHardware = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();

      if (!hasHardware) return 'No biometric hardware on this device.';
      if (!canCheck) {
        return 'Biometrics not enrolled. Set up a screen lock and fingerprint/face.';
      }
      if (enrolled.isEmpty) {
        return 'No biometrics enrolled. Add fingerprint/face in phone settings.';
      }
      return 'Available: ${enrolled.map((e) => e.name).join(', ')}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Enrolled biometric kinds, e.g. [BiometricType.face].
  Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// True when a face-unlock path is available.
  ///
  /// On Android the system face prompt is unreliable — OEM face unlock (e.g.
  /// vivo Face Wake) is usually not exposed to apps, and requesting a weak
  /// biometric silently falls back to the fingerprint prompt. So on Android,
  /// Face lock uses the in-app camera scan and is available whenever a front
  /// camera exists. On iOS the system Face ID prompt is used.
  Future<bool> get hasFaceId async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final cams = await availableCameras();
        return cams.any((c) => c.lensDirection == CameraLensDirection.front);
      } catch (_) {
        return false;
      }
    }
    final types = await availableTypes();
    return types.contains(BiometricType.face);
  }

  /// True when the device has an enrolled, fingerprint-capable biometric.
  ///
  /// On Android this is the `strong` (Class 3) classification.
  Future<bool> get hasFingerprint async {
    final types = await availableTypes();
    return types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong);
  }

  /// One combined probe so callers (and tests) can read all three states in
  /// a single call.
  Future<BiometricAvailability> get availability async {
    return BiometricAvailability(
      any: await isAvailable,
      fingerprint: await hasFingerprint,
      face: await hasFaceId,
    );
  }

  /// Authenticates with the generic biometric prompt (system picks the
  /// enrolled biometric). Used for the login screen and as a fallback where
  /// the native class-restricted channel isn't available (iOS/web).
  Future<bool> authenticate({String reason = 'Unlock ArtVault'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      // Cancellation, missing hardware/enrollment, or lockout all mean the
      // user is not authenticated.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Authenticates using ONLY strong biometrics — fingerprint (Class 3).
  /// The device PIN/pattern/password never satisfies this prompt.
  Future<bool> authenticateFingerprint({
    String reason = 'Unlock ArtVault',
  }) async {
    try {
      final ok = await _native.invokeMethod<bool>('authenticateClass', {
        'class': 'strong',
      });
      return ok ?? false;
    } catch (_) {
      // No native channel (iOS / web / desktop) — fall back to the standard
      // biometric prompt for that platform.
      return authenticate(reason: reason);
    }
  }

  /// Authenticates with the face unlock method.
  ///
  /// - iOS: system Face ID prompt (real identity match).
  /// - Android: returns [FaceAuthResult.needsCameraScan] so the caller can run
  ///   the in-app camera face scan — the system face prompt cannot be trusted
  ///   here (it shows the fingerprint prompt instead of a face scan).
  Future<FaceAuthResult> authenticateFace({
    String reason = 'Unlock ArtVault',
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return FaceAuthResult.needsCameraScan;
    }
    final ok = await authenticate(reason: reason);
    return ok ? FaceAuthResult.success : FaceAuthResult.failed;
  }

  /// Stops any pending authentication session.
  Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
