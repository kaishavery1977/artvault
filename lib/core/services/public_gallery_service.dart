import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/painting.dart';
import '../../data/remote/cloud_backend.dart';
import '../utils/formatters.dart';
import 'file_storage_service.dart';

/// Builds a self-contained, shareable HTML gallery page from the owner's
/// curated selection (paintings flagged "include in public gallery"), and
/// publishes it to a **public** Storage path so the download URL works for
/// anyone with the link.
///
/// The page embeds every image as base64, so the HTML alone is the gallery —
/// no backend is involved once it's opened. Publishing is best-effort: when
/// the cloud isn't ready (offline / rules not deployed), callers fall back
/// to sharing the HTML file directly.
class PublicGalleryService {
  PublicGalleryService._();

  static final PublicGalleryService instance = PublicGalleryService._();

  /// Stable storage path per owner — sharing the same link twice republishes
  /// the page in place, so an old link keeps pointing at the fresh gallery.
  static String storagePathFor(String ownerUid) =>
      'public_galleries/gallery-$ownerUid/page.html';

  /// One page per artwork: image, title, artist, year, medium and location.
  /// Only fields the owner opted into are shown — never price.
  String buildHtml(List<Painting> paintings) {
    final cards = paintings.map(_cardHtml).join('\n');
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ArtVault — Public Gallery</title>
<style>
  body { margin:0; background:#101014; color:#eaeaf0; font-family:-apple-system,
    BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; }
  header { padding:48px 24px 8px; text-align:center; }
  header h1 { margin:0; font-size:28px; letter-spacing:.5px; }
  header p { color:#9a9aa6; margin:8px 0 0; font-size:14px; }
  main { max-width:1060px; margin:0 auto; padding:28px 24px 64px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr));
    gap:20px; }
  .card { background:#1b1b22; border:1px solid #2a2a33; border-radius:14px;
    overflow:hidden; }
  .card img { width:100%; height:240px; object-fit:cover; display:block;
    background:#000; }
  .card .meta { padding:14px 16px 16px; }
  .card h2 { margin:0; font-size:17px; }
  .card .artist { color:#c8c8d4; font-size:13px; margin-top:2px; }
  .card .detail { color:#8f8f9d; font-size:12px; margin-top:8px; line-height:1.5; }
  .card .location { display:inline-block; margin-top:10px; font-size:11px;
    font-weight:600; color:#8ab4ff; border:1px solid #33415e;
    padding:3px 10px; border-radius:999px; }
  footer { text-align:center; color:#5c5c68; font-size:12px; padding:0 24px 40px; }
</style>
</head>
<body>
<header>
  <h1>ArtVault Gallery</h1>
  <p>A curated collection &middot; ${paintings.length} artwork${paintings.length == 1 ? '' : 's'}</p>
</header>
<main>
${paintings.isEmpty ? '<p style="text-align:center;color:#8f8f9d">Nothing here yet.</p>' : '<div class="grid">$cards</div>'}
</main>
<footer>Shared from ArtVault</footer>
</body>
</html>
''';
  }

  String _cardHtml(Painting painting) {
    final image = _imageTag(painting);
    final year = painting.dateCreated;
    final detailParts = <String>[
      if (painting.medium.isNotEmpty) painting.medium,
      if (year != null && year.isNotEmpty) year,
    ];
    final detail = detailParts.isEmpty
        ? ''
        : '<div class="detail">${_escape(detailParts.join(' &middot; '))}</div>';
    final location = painting.location.isEmpty
        ? ''
        : '<div class="location">${_escape(painting.location.toUpperCase())}</div>';
    return '''
    <div class="card">
      $image
      <div class="meta">
        <h2>${_escape(painting.title)}</h2>
        ${painting.artistName.isEmpty ? '' : '<div class="artist">${_escape(painting.artistName)}</div>'}
        $detail
        $location
      </div>
    </div>''';
  }

  String _imageTag(Painting painting) {
    if (painting.coverImageUrl.isNotEmpty) {
      return '<img src="${_escape(painting.coverImageUrl)}" alt="${_escape(painting.title)}">';
    }
    final path = painting.coverImagePath;
    if (path.isNotEmpty && File(path).existsSync()) {
      final bytes = File(path).readAsBytesSync();
      final b64 = base64Encode(bytes);
      final mime = p.extension(path).toLowerCase() == '.png'
          ? 'image/png'
          : 'image/jpeg';
      return '<img src="data:$mime;base64,$b64" alt="${_escape(painting.title)}">';
    }
    return '<img src="" alt="">';
  }

  /// Publishes the page and returns its public download URL, or null when the
  /// cloud isn't ready (caller then shares the HTML file instead).
  Future<String?> publish(
    List<Painting> paintings, {
    required String ownerUid,
  }) async {
    if (ownerUid.isEmpty || !CloudBackend.instance.isReady) return null;
    final html = buildHtml(paintings);
    final bytes = Uint8List.fromList(utf8.encode(html));
    return CloudBackend.instance.uploadBytes(
      storagePathFor(ownerUid),
      bytes,
      contentType: 'text/html; charset=utf-8',
    );
  }

  /// Writes the page to the exports folder so it can be shared as a file
  /// (the offline / rules-not-deployed fallback).
  Future<File> writeLocalHtml(List<Painting> paintings) async {
    final html = buildHtml(paintings);
    final file = File(
      p.join(
        FileStorageService.instance.exportsDir.path,
        'public_gallery_${Formatters.fileStamp(DateTime.now())}.html',
      ),
    );
    await file.writeAsString(html);
    return file;
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
