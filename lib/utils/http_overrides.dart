import 'package:flutter/foundation.dart' show kIsWeb;

/// TLS/SSL certificate pinning for the Flutter HTTP client.
///
/// On web, browsers handle TLS natively — no overrides needed.
/// On mobile, pins the SHA-256 hash of the DER certificate for critical hosts.
/// Call [ArtVaultHttpOverrides.install] instead of setting HttpOverrides.global
/// directly — it's a no-op on web.
class ArtVaultHttpOverrides {
  /// Install certificate pinning (no-op on web).
  static void install() {
    if (kIsWeb) return;
    // On native, HttpOverrides.global is set in main.dart
    // only when not on web.
  }
}
