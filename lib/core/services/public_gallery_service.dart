import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import '../../data/models/painting.dart';
import '../../data/remote/cloud_backend.dart';
import '../../firebase_options.dart';
import '../utils/formatters.dart';
import 'file_storage_service.dart';

/// Current state of the owner's published gallery link.
///
/// [url] is the rules-gated page URL — it only resolves while [active] is
/// true and [expiresAt] (when set) is still in the future.
class PublicGalleryStatus {
  final bool active;
  final String token;
  final DateTime? expiresAt;
  final String? url;

  /// Number of page views recorded for this link (Pro analytics). Null
  /// when the link was published before view tracking existed.
  final int? views;

  /// Watermark text stamped across the shared page (Pro). Empty = none.
  final String watermark;

  const PublicGalleryStatus({
    required this.active,
    required this.token,
    this.expiresAt,
    this.url,
    this.views,
    this.watermark = '',
  });
}

/// Builds a self-contained, shareable HTML gallery page from the owner's
/// curated selection (paintings flagged "include in public gallery"), and
/// publishes it to a **revocable** Storage path so the link can be expired
/// or killed at any time.
///
/// Revocation works because the page lives under a per-link secret token and
/// is served through a **plain, rules-gated URL** (never the tokenized
/// `getDownloadURL`, which would bypass rules forever). Every read is checked
/// against a Firestore link document (`public_galleries/{uid}`) holding the
/// token, an `active` flag and an optional `expiresAt` — revoke or expire
/// the link and the page stops resolving.
///
/// The page embeds every image as base64, so the HTML alone is the gallery —
/// no backend is involved once it's opened. Publishing is best-effort: when
/// the cloud isn't ready (offline / rules not deployed), callers fall back
/// to sharing the HTML file directly.
class PublicGalleryService {
  PublicGalleryService._();

  static final PublicGalleryService instance = PublicGalleryService._();

  static const String _collection = 'public_galleries';

  /// Storage path for the owner's gallery page. [token] is a high-entropy
  /// secret embedded in the path itself; reads are additionally gated on
  /// the Firestore link document, so the page stops resolving the moment
  /// the link is revoked or expires.
  static String storagePathFor(String ownerUid, String token) =>
      'public_galleries/$ownerUid/$token/page.html';

  /// Fresh unguessable token for a new gallery link (URL-safe, no padding).
  static String newToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(18, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// One page per artwork: image, title, artist, year, medium and location.
  /// Only fields the owner opted into are shown — never price. When
  /// [watermark] is non-empty the page carries a subtle diagonal watermark
  /// on every artwork image (Pro feature) and the stats beacon that bumps
  /// the per-link view counter. [token] is the link's secret token — the
  /// beacon writes to the token-scoped counter so analytics can never be
  /// forged against a different (or revoked) link.
  String buildHtml(
    List<Painting> paintings, {
    String watermark = '',
    String? ownerUid,
    String? token,
  }) {
    final cards = paintings.map((p) => _cardHtml(p, watermark: watermark)).join('\n');
    final wmCss = watermark.isEmpty
        ? ''
        : '''
  .imgwrap { position:relative; }
  .wm { position:absolute; inset:0; display:flex; align-items:center;
    justify-content:center; pointer-events:none; }
  .wm::after { content:attr(data-mark); transform:rotate(-18deg);
    font-size:22px; font-weight:700; letter-spacing:2px; color:rgba(255,255,255,.28);
    border:1px solid rgba(255,255,255,.22); padding:6px 22px; border-radius:6px;
    white-space:nowrap; text-shadow:0 1px 3px rgba(0,0,0,.5); }''';
    final beacon = _viewBeacon(ownerUid, watermark, token);
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
    background:#000; }$wmCss
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
$beacon
</body>
</html>
''';
  }

  /// The optional Pro view-tracking beacon. Resolves the Firebase project


  String _cardHtml(Painting painting, {String watermark = ''}) {
    final image = _imageTag(painting);
    final wm = watermark.isEmpty
        ? ''
        : '<div class="wm" data-mark="${_escape(watermark)}"></div>';
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
      <div class="imgwrap">$image$wm</div>
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

  /// Publishes the page under a fresh link token and returns its
  /// rules-gated URL, or null when the cloud isn't ready (caller then
  /// shares the HTML file instead). Re-publishing replaces the previous
  /// link: the old page is deleted and the link document now points at the
  /// new token. A non-empty [watermark] stamps the owner's name across
  /// every artwork image (Pro) and arms the per-link view beacon.
  Future<String?> publish(
    List<Painting> paintings, {
    required String ownerUid,
    String watermark = '',
  }) async {
    if (ownerUid.isEmpty || !CloudBackend.instance.isReady) return null;

    // Best-effort cleanup of any previous link so re-publishing doesn't
    // leave orphaned pages behind.
    final previous = await status(ownerUid);
    if (previous != null && previous.token.isNotEmpty) {
      await CloudBackend.instance.deleteFile(
        storagePathFor(ownerUid, previous.token),
      );
    }

    final token = newToken();
    final html = buildHtml(
      paintings,
      watermark: watermark,
      ownerUid: ownerUid,
      token: token,
    );
    final bytes = Uint8List.fromList(utf8.encode(html));
    final url = await CloudBackend.instance.uploadBytesPublic(
      storagePathFor(ownerUid, token),
      bytes,
      contentType: 'text/html; charset=utf-8',
    );
    if (url == null) return null;

    await CloudBackend.instance.upsert(_collection, ownerUid, {
      'ownerUid': ownerUid,
      'token': token,
      'active': true,
      'expiresAt': null,
      'watermark': watermark,
      'updatedAt': DateTime.now(),
    });
    return url;
  }

  /// Stops the shared page resolving: marks the link inactive and deletes
  /// the published page (best effort) so nothing lingers in storage.
  Future<void> revoke(String ownerUid) async {
    if (ownerUid.isEmpty || !CloudBackend.instance.isReady) return;
    final current = await status(ownerUid);
    if (current != null && current.token.isNotEmpty) {
      await CloudBackend.instance.deleteFile(
        storagePathFor(ownerUid, current.token),
      );
    }
    await CloudBackend.instance.upsert(_collection, ownerUid, {
      'active': false,
      'updatedAt': DateTime.now(),
    });
  }

  /// Sets when the shared page stops resolving (null = never expires).
  Future<void> setExpiry(String ownerUid, DateTime? expiresAt) async {
    if (ownerUid.isEmpty || !CloudBackend.instance.isReady) return;
    await CloudBackend.instance.upsert(_collection, ownerUid, {
      'expiresAt': expiresAt,
      'updatedAt': DateTime.now(),
    });
  }

  /// Current link status, or null when the gallery was never published.
  Future<PublicGalleryStatus?> status(String ownerUid) async {
    if (ownerUid.isEmpty || !CloudBackend.instance.isReady) return null;
    final doc = await CloudBackend.instance.fetchDoc(_collection, ownerUid);
    if (doc == null) return null;
    final token = doc['token'] as String? ?? '';
    final rawExpiry = doc['expiresAt'];
    DateTime? expiresAt;
    if (rawExpiry is Timestamp) {
      expiresAt = rawExpiry.toDate();
    } else if (rawExpiry is DateTime) {
      expiresAt = rawExpiry;
    }
    int? views;
    try {
      // Token-scoped counter: each published link has its own stats doc,
      // so analytics never bleed across re-published (or revoked) links.
      final stats = await CloudBackend.instance.fetchDoc(
        _collection,
        '$ownerUid/stats/$token',
      );
      final raw = stats?['views'];
      if (raw is num) views = raw.toInt();
    } catch (_) {
      views = null; // stats subcollection may not exist yet
    }
    return PublicGalleryStatus(
      active: doc['active'] == true,
      token: token,
      expiresAt: expiresAt,
      watermark: (doc['watermark'] as String?) ?? '',
      views: views,
      url: token.isEmpty
          ? null
          : CloudBackend.instance.publicUrlFor(
              storagePathFor(ownerUid, token),
            ),
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

  /// The optional Pro view-tracking beacon embedded in the page. Resolves
  /// the Firebase project once so an unknown platform (tests, desktop)
  /// simply skips the beacon instead of breaking the page.
  ///
  /// The counter is token-scoped (`public_galleries/{uid}/stats/{token}`) and
  /// bumped atomically via a Firestore REST commit with a server-side
  /// INCREMENT transform — no read-modify-write race, and a revoked or
  /// re-published link can never receive forged increments.
  static String _viewBeacon(String? ownerUid, String watermark, String? token) {
    if (ownerUid == null || token == null || token.isEmpty || watermark.isEmpty) {
      return '';
    }
    String projectId;
    String apiKey;
    try {
      projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    } catch (_) {
      return '';
    }
    final commitUrl =
        'https://firestore.googleapis.com/v1/projects/$projectId/'
        'databases/(default)/documents:commit?key=$apiKey';
    final docName =
        'projects/$projectId/databases/(default)/documents/'
        'public_galleries/$ownerUid/stats/$token';
    return '''
<script>
(function () {
  // Pro analytics: atomically increment this link's view counter
  // (best-effort, fire-and-forget; server-side INCREMENT transform).
  var url = ${_jsStr(commitUrl)};
  var docName = ${_jsStr(docName)};
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      writes: [{
        update: {
          name: docName,
          fields: {},
          updateMask: { fieldPaths: ['views'] }
        },
        updateTransforms: [{
          fieldPath: 'views',
          setToServerValue: 'INCREMENT',
          increment: { integerValue: '1' }
        }]
      }]
    })
  }).catch(function () {});
})();
</script>''';
  }

  static String _jsStr(String value) =>
      "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
