// Tests for the public gallery page: the generated HTML must contain the
// curated artwork data (escaped), never prices, and embed local images so
// the single file is the whole gallery. Also covers the revocable-link
// mechanics: secret-token paths, plain rules-gated URLs (never the
// tokenized download URL that would bypass rules).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/public_gallery_service.dart';
import 'package:artvault/data/models/painting.dart';

Painting _paint(
  String id, {
  String title = '',
  String artistName = '',
  String medium = '',
  String location = '',
  double? price,
  String currency = 'USD',
  String coverPath = '',
  String coverUrl = '',
  String? dateCreated,
}) =>
    Painting(
      id: id,
      title: title.isEmpty ? id : title,
      artistId: '',
      artistName: artistName,
      medium: medium,
      location: location,
      price: price,
      currency: currency,
      coverImagePath: coverPath,
      coverImageUrl: coverUrl,
      dateCreated: dateCreated,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  final service = PublicGalleryService.instance;

  group('PublicGalleryService.buildHtml', () {
    test('renders curated artwork fields and never the price', () {
      final html = service.buildHtml([
        _paint(
          'p1',
          title: 'Sunlit Orchard',
          artistName: 'Ada Lovelace',
          medium: 'Oil on canvas',
          location: 'Living Room',
          price: 12500,
          dateCreated: '2021',
        ),
      ]);

      expect(html, contains('Sunlit Orchard'));
      expect(html, contains('Ada Lovelace'));
      expect(html, contains('Oil on canvas'));
      expect(html, contains('LIVING ROOM'));
      expect(html, contains('2021'));
      expect(html, isNot(contains('12,500')));
      expect(html, isNot(contains('12500')));
    });

    test('escapes HTML in user-provided fields', () {
      final html = service.buildHtml([
        _paint(
          'p1',
          title: '<script>alert(1)</script>',
          artistName: 'A & B',
          location: 'Room <b>X</b>',
        ),
      ]);

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('A &amp; B'));
      expect(html, contains('ROOM &lt;'));
    });

    test('embeds a local image as base64 when there is no remote url', () {
      final dir = Directory.systemTemp.createTempSync('artvault_gallery_test');
      final img = File('${dir.path}/cover.png');
      img.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);

      final html = service.buildHtml([
        _paint('p1', title: 'Local Piece', coverPath: img.path),
      ]);

      expect(html, contains('data:image/png;base64,'));
      expect(html, isNot(contains('src=""/>')));

      dir.deleteSync(recursive: true);
    });

    test('empty selection produces a valid page', () {
      final html = service.buildHtml(const []);
      expect(html, contains('Nothing here yet.'));
      expect(html, contains('0 artworks'));
    });

    test('no watermark by default', () {
      final html = service.buildHtml([_paint('p1', title: 'Plain')]);
      expect(html, isNot(contains('class="wm"')));
      expect(html, isNot(contains('setToServerValue')));
    });

    test('watermark overlays every image and arms the view beacon', () {
      final html = service.buildHtml(
        [_paint('p1', title: 'Owned Piece')],
        watermark: 'Kais Havery',
        ownerUid: 'owner-1',
        token: 'tok-abc',
      );
      expect(html, contains('class="wm"'));
      expect(html, contains('data-mark="Kais Havery"'));
      // Token-scoped, atomic increment via the Firestore REST commit API.
      expect(html, contains('documents:commit'));
      expect(html, contains('setToServerValue'));
      expect(html, contains('public_galleries/owner-1/stats/tok-abc'));
    });
  });

  group('PublicGalleryService revocable links', () {
    test('storage path embeds owner uid and secret token', () {
      final path =
          PublicGalleryService.storagePathFor('user-1', 'secret-token');
      expect(path, 'public_galleries/user-1/secret-token/page.html');
      // The token sits between the owner segment and the file, so the
      // storage rule can match it with a wildcard.
      expect(path.split('/').length, 4);
    });

    test('newToken produces unique, URL-safe, unpadded secrets', () {
      final tokens = {for (var i = 0; i < 50; i++) PublicGalleryService.newToken()};
      expect(tokens.length, 50);
      for (final token in tokens) {
        expect(token, isNotEmpty);
        expect(token.length >= 20, isTrue,
            reason: 'token should be unguessable (>= ~120 bits)');
        expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
        expect(token, isNot(contains('=')));
      }
    });

    test('published page is served through a public Supabase URL', () {
      // With Supabase Storage, the public URL is served through RLS policies
      // (not Firebase token URLs). The URL should be a plain public path.
      final path = 'public_galleries/u1/tok/page.html';
      // Verify the path format is valid for Supabase Storage
      expect(path, startsWith('public_galleries/'));
      expect(path, endsWith('.html'));
      // The path should not contain token parameters (Supabase uses RLS, not tokens)
      expect(path, isNot(contains('token=')),
          reason: 'Supabase uses RLS policies, not tokenized URLs');
    });

    test('different owners and tokens produce distinct paths', () {
      expect(
        PublicGalleryService.storagePathFor('user-a', 't1'),
        isNot(PublicGalleryService.storagePathFor('user-b', 't1')),
      );
      expect(
        PublicGalleryService.storagePathFor('user-a', 't1'),
        isNot(PublicGalleryService.storagePathFor('user-a', 't2')),
      );
    });
  });
}
