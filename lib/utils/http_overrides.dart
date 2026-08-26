/// TLS/SSL pinning support for the Flutter HTTP client.
///
/// This file provides a skeleton implementation that can be used to reject
/// connections whose peer certificate does not match an expected SHA‑256
/// fingerprint (base64).  It is intentionally kept minimal so the compiler
/// does not require a full [HttpClient] subclass.
///
/// ⚠️  Before enabling pinning in production, obtain the real SHA‑256
/// fingerprints (base64, no padding) for each host your app contacts
/// (Firebase APIs, Cloud Functions URLs, custom back‑ends) from crt.sh or
/// the server's TLS certificate, and replace the placeholder entries below.
///
/// To use:
///   1. Fill in `_pinnedFingerprints` with real fingerprints.
///   2. Add `HttpOverrides.global = MyHttpOverrides();` early in `main()`,
///      before `runApp`.
///   3. Re‑run `flutter build` to regenerate the app bundle.
///
/// Without real fingerprints the pinning check is a no‑op (connection always
/// allowed).  The code compiles but does not enforce pinning.
///
/// The following types are placeholders and will need concrete implementations
/// for a production build:
///   • [MyHttpOverrides] extends [http.Hoverrides]
///   • [_PinnedClient] extends [http.BaseClient]
///   • [_pinnedFingerprints] maps hosts to real SHA‑256 fingerprints.
library;

/// Host → expected SHA‑256 fingerprint (base64, without padding).
/// Replace every placeholder with the actual fingerprint of the corresponding
/// host before deploying to a production build.
// ignore: unused_element
// ignore: unused_element - populated with real fingerprints before release
const Map<String, String> _pinnedFingerprints = {
  'example.host': 'placeholder_fingerprint',
};