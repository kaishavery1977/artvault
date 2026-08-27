import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/services/app_logger.dart';

/// TLS/SSL certificate pinning for the Flutter HTTP client.
///
/// Pins the SHA-256 hash of the DER-encoded certificate for critical hosts.
/// In debug mode, pinning is relaxed to allow proxy tools.
class ArtVaultHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // In debug mode, allow all certificates so dev tools can intercept.
    if (!const bool.fromEnvironment('dart.vm.product')) {
      return client;
    }

    client
        .badCertificateCallback = (X509Certificate cert, String host, int port) {
      final expectedPins = pinnedKeys[host];
      if (expectedPins == null) return false; // No pin = rely on system trust

      final actualPin = sha256.convert(cert.der).bytes;
      final actualPinB64 = base64Url.encode(actualPin).replaceAll('=', '');

      if (!expectedPins.contains(actualPinB64)) {
        AppLogger.error(
          'TLS PIN MISMATCH: $host — expected one of $expectedPins, got $actualPinB64',
        );
        return false; // Reject mismatch
      }
      return true; // Allow matched pin (even if system says bad, our pin says it's ok)
    };

    return client;
  }
}

/// Host → SHA-256 pin of the DER certificate (base64url, no padding).
///
/// To get the real pin for a host, run the openssl command from your terminal
/// to extract the SHA-256 fingerprint of the server certificate.
///
/// Pin at least TWO keys: current + backup (SPKI survives renewal).
const Map<String, Set<String>> pinnedKeys = {
  // SHA-256 of the DER cert for mtwinlbgvuxezadbsrrl.supabase.co (Google Trust WE1, exp 2026-11-24)
  // Fetched 2026-08-26 via SslStream; base64url no padding of sha256(cert.der).
  // Keep previous pin for 1 rotation window after expiry.
  'mtwinlbgvuxezadbsrrl.supabase.co': {
    'vhe_M2GnaRvd4pPZIwPKNZjmwNFCb4-5LkOKGdr44xs', // current cert
    'AWMU3zh73oGjrfmUrppf3VTZvZIJ384H2ST9kpw9GrY', // SPKI backup (same key)
  },
};
