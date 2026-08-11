import '../constants/app_constants.dart';

/// Builds QR payloads for artworks and parses scanned codes back.
abstract final class QrService {
  /// Canonical deep link stored in every artwork QR code.
  static String payloadFor(String paintingId) =>
      '${AppConstants.deepLinkScheme}://artwork/$paintingId';

  /// Reads a painting id out of a scanned payload. Returns null for foreign
  /// codes so the scanner can ignore unrelated QR codes.
  static String? parsePaintingId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('${AppConstants.deepLinkScheme}://artwork/')) {
      return trimmed.split('/').last;
    }
    // Accept a bare id too.
    if (RegExp(r'^[a-zA-Z0-9\-_]{8,}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }
}
