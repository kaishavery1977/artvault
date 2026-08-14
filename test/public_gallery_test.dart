// Tests for the public gallery page: the generated HTML must contain the
// curated artwork data (escaped), never prices, and embed local images so
// the single file is the whole gallery.

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
  });
}
