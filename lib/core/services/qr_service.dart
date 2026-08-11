import '../constants/app_constants.dart';

/// A decoded ArtVault QR code.
class QrPayload {
  final String paintingId;
  final String? title;
  final String? artistName;

  const QrPayload({required this.paintingId, this.title, this.artistName});
}

/// Builds QR payloads for artworks and parses scanned codes back.
///
/// The code carries the painting's local id plus its title/artist. The id is
/// device-local, so the title/artist let scanners on *other* devices find the
/// artwork (or offer to add it) instead of showing "Painting not found".
abstract final class QrService {
  /// Canonical deep link stored in every artwork QR code.
  static String payloadFor(
    String paintingId, {
    String? title,
    String? artistName,
  }) {
    final sb = StringBuffer(
      '${AppConstants.deepLinkScheme}://artwork/$paintingId',
    );
    final params = <String>[];
    if (title != null && title.isNotEmpty) {
      params.add('t=${Uri.encodeQueryComponent(title)}');
    }
    if (artistName != null && artistName.isNotEmpty) {
      params.add('a=${Uri.encodeQueryComponent(artistName)}');
    }
    if (params.isNotEmpty) sb.write('?${params.join('&')}');
    return sb.toString();
  }

  /// Parses a scanned payload. Returns null for foreign codes so the
  /// scanner can ignore unrelated QR codes.
  static QrPayload? parsePayload(String raw) {
    final trimmed = raw.trim();
    final prefix = '${AppConstants.deepLinkScheme}://artwork/';
    if (trimmed.startsWith(prefix)) {
      final rest = trimmed.substring(prefix.length);
      final idPart = rest.split('?').first;
      if (idPart.isEmpty) return null;

      String? title;
      String? artistName;
      final query = rest.contains('?') ? rest.split('?').last : '';
      for (final pair in query.split('&')) {
        if (pair.isEmpty) continue;
        final kv = pair.split('=');
        if (kv.length != 2) continue;
        final key = kv[0];
        final value = Uri.decodeQueryComponent(kv[1]);
        if (key == 't') title = value;
        if (key == 'a') artistName = value;
      }
      return QrPayload(
        paintingId: idPart,
        title: title,
        artistName: artistName,
      );
    }
    // Accept a bare id too.
    if (RegExp(r'^[a-zA-Z0-9\-_]{8,}$').hasMatch(trimmed)) {
      return QrPayload(paintingId: trimmed);
    }
    return null;
  }

  /// Reads a painting id out of a scanned payload.
  static String? parsePaintingId(String raw) => parsePayload(raw)?.paintingId;
}
