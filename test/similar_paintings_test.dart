// Unit tests for the visual-similarity scorer that powers the detail
// screen's "Similar paintings" rail. The scorer blends the perceptual hash
// with palette, tags, category/medium/style and tonal character, so related
// works surface even when one side has no hash yet.

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/ai_service.dart';
import 'package:artvault/data/models/painting.dart';

Painting _paint({
  required String id,
  String category = '',
  String medium = '',
  String style = '',
  List<String> tags = const [],
  List<String> aiTags = const [],
  List<String> colors = const [],
  String hash = '',
  double brightness = 0.5,
  double contrast = 0.5,
  bool isDeleted = false,
}) => Painting(
  id: id,
  title: id,
  artistId: '',
  artistName: 'Test Artist',
  category: category,
  medium: medium,
  style: style,
  tags: tags,
  aiTags: aiTags,
  dominantColors: colors,
  aiHash: hash,
  brightness: brightness,
  contrast: contrast,
  isDeleted: isDeleted,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  group('AiService.findSimilar', () {
    test('ranks palette+tag twins above unrelated works', () {
      final base = _paint(
        id: 'a',
        category: 'Painting',
        medium: 'Oil',
        tags: ['portrait', 'blue'],
        colors: ['#1E3A5F', '#C9A227'],
        hash: 'h0',
      );
      final twin = _paint(
        id: 'b',
        category: 'Painting',
        medium: 'Oil',
        tags: ['portrait', 'blue', 'formal'],
        colors: ['#1E3A5F', '#C9A227', '#2B2B2B'],
        hash: 'h0', // identical hash = near-identical image
      );
      final landscape = _paint(
        id: 'c',
        category: 'Landscape',
        medium: 'Watercolour',
        tags: ['garden'],
        colors: ['#7BA05B', '#E8E3C9'],
      );

      final result = AiService.instance.findSimilar(base, [
        base,
        twin,
        landscape,
      ]);

      expect(result, isNotEmpty);
      expect(result.first.painting.id, 'b');
      expect(result.first.similarity, greaterThan(0.5));
    });

    test('excludes the painting itself and deleted works', () {
      final base = _paint(id: 'a', tags: ['x'], colors: ['#111111']);
      final deleted = _paint(
        id: 'b',
        tags: ['x'],
        colors: ['#111111'],
        isDeleted: true,
      );

      final result = AiService.instance.findSimilar(base, [base, deleted]);

      expect(result.map((m) => m.painting.id), isNot(contains('a')));
      expect(result.map((m) => m.painting.id), isNot(contains('b')));
    });

    test('scores hash-less paintings via palette and tags (renormalised)', () {
      final base = _paint(
        id: 'a',
        tags: ['still-life'],
        colors: ['#D4A017', '#8B4513'],
        hash: 'abcdef',
      );
      final similar = _paint(
        id: 'b',
        tags: ['still-life', 'fruit'],
        colors: ['#D4A017', '#8B4513', '#4A3728'],
      );

      final result = AiService.instance.findSimilar(base, [base, similar]);

      expect(result, isNotEmpty);
      expect(result.first.painting.id, 'b');
      expect(result.first.similarity, greaterThan(0.3));
    });

    test('threshold filters weak matches, limit caps the list', () {
      final base = _paint(id: 'a', colors: ['#111111']);
      final weak = _paint(id: 'b', colors: ['#EEEEEE'], category: 'Sculpture');
      final strong = _paint(
        id: 'c',
        colors: ['#111111'],
        tags: ['same'],
        category: 'Painting',
      );

      final strict = AiService.instance.findSimilar(base, [
        base,
        weak,
        strong,
      ], threshold: 0.9);
      // Weak (palette-less) match is filtered; the strong palette twin stays.
      expect(strict.map((m) => m.painting.id), ['c']);

      final limited = AiService.instance.findSimilar(
        base,
        List.generate(
          10,
          (i) => _paint(id: 'p$i', colors: ['#111111'], tags: ['same']),
        ),
        limit: 3,
      );
      expect(limited.length, lessThanOrEqualTo(3));
    });

    test('identical twins clamp at a perfect 1.0', () {
      final a = _paint(id: 'a', colors: ['#123456'], tags: ['x']);
      final b = _paint(id: 'b', colors: ['#123456'], tags: ['x']);

      final result = AiService.instance.findSimilar(a, [a, b]);

      expect(result.first.painting.id, 'b');
      expect(result.first.similarity, 1.0);
    });
  });
}
