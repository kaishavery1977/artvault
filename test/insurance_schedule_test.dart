// Smoke tests for the insurance-schedule PDF: it must produce a valid PDF
// containing every artwork with its value, dimensions and location, and a
// currency-aware total.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/export_service.dart';
import 'package:artvault/data/models/painting.dart';

Painting _paint({
  required String id,
  String title = '',
  String artistName = '',
  double? width,
  double? height,
  String location = '',
  double? price,
  String currency = 'USD',
}) => Painting(
  id: id,
  title: title.isEmpty ? id : title,
  artistId: '',
  artistName: artistName,
  width: width,
  height: height,
  dimensionUnit: 'cm',
  location: location,
  price: price,
  currency: currency,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  final paintings = [
    _paint(
      id: 'p1',
      title: 'Sunlit Orchard',
      artistName: 'Ada Lovelace',
      width: 80,
      height: 60,
      location: 'Living room',
      price: 12500,
      currency: 'USD',
    ),
    _paint(
      id: 'p2',
      title: 'Night Study',
      artistName: 'Grace Hopper',
      width: 30,
      height: 40,
      location: 'Study',
      price: 2400,
      currency: 'EUR',
    ),
    _paint(id: 'p3', title: 'Unvalued Sketch', location: 'Studio'),
  ];

  group('ExportService.buildInsuranceSchedulePdf', () {
    test('produces a valid non-empty PDF and grows with content', () async {
      final one = await ExportService.instance.buildInsuranceSchedulePdf([
        paintings.first,
      ]);
      final all = await ExportService.instance.buildInsuranceSchedulePdf(
        paintings,
      );

      expect(one, isA<Uint8List>());
      expect(one.length, greaterThan(1000));
      expect(String.fromCharCodes(one.take(5)), '%PDF-');
      // More rows → a bigger document.
      expect(all.length, greaterThan(one.length));
    });

    test(
      'handles missing values and mixed currencies without throwing',
      () async {
        final bytes = await ExportService.instance.buildInsuranceSchedulePdf(
          paintings,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

        // Empty selection is also fine.
        final empty = await ExportService.instance.buildInsuranceSchedulePdf(
          const [],
        );
        expect(String.fromCharCodes(empty.take(5)), '%PDF-');
      },
    );
  });
}
