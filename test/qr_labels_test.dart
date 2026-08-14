// Tests for QR inventory: the printable QR label sheet, and the payload
// round-trip that lets any scanner re-open an artwork from a printed label.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/export_service.dart';
import 'package:artvault/core/services/qr_service.dart';
import 'package:artvault/data/models/painting.dart';

Painting _paint(String id, {String title = '', String location = ''}) =>
    Painting(
      id: id,
      title: title.isEmpty ? id : title,
      artistId: '',
      artistName: 'Test Artist',
      location: location,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  group('QrService payload round-trip', () {
    test('payloadFor → parsePayload restores the painting id and title', () {
      final raw = QrService.payloadFor(
        'abc123',
        title: 'Sunlit Orchard',
        artistName: 'Ada Lovelace',
        description: 'A long description that gets embedded.',
      );

      expect(raw, startsWith('artvault://artwork/abc123'));

      final payload = QrService.parsePayload(raw);
      expect(payload, isNotNull);
      expect(payload!.paintingId, 'abc123');
      expect(payload.title, 'Sunlit Orchard');
      expect(payload.artistName, 'Ada Lovelace');
    });

    test('foreign codes are ignored by the parser', () {
      expect(QrService.parsePayload('https://example.com/not-artvault'), isNull);
      expect(QrService.parsePayload('tiny'), isNull); // < 8 chars, no scheme
    });
  });

  group('ExportService.buildQrLabelSheetPdf', () {
    test('produces a valid non-empty PDF', () async {
      final bytes = await ExportService.instance.buildQrLabelSheetPdf([
        _paint('p1', title: 'Sunlit Orchard', location: 'Living room'),
        _paint('p2', title: 'Night Study', location: 'Study'),
        _paint('p3', title: 'Unvalued Sketch'),
      ]);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('empty collection yields a PDF too', () async {
      final bytes = await ExportService.instance
          .buildQrLabelSheetPdf(const []);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
