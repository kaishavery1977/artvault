import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../data/models/artist.dart';
import '../../data/models/painting.dart';
import '../constants/app_constants.dart';
import '../utils/image_utils.dart';

/// Result of a duplicate scan against the existing collection.
class DuplicateMatch {
  final Painting painting;
  final double similarity;

  const DuplicateMatch(this.painting, this.similarity);
}

/// Natural-language search predicate parsed from voice/text queries.
class SearchQuery {
  String? artist;
  String? medium;
  String? category;
  String? style;
  String? colorHex;
  double? minDimension;
  double? maxDimension;
  bool latestOnly = false;
  String? freeText;

  bool get isEmpty =>
      artist == null &&
      medium == null &&
      category == null &&
      style == null &&
      colorHex == null &&
      minDimension == null &&
      maxDimension == null &&
      !latestOnly &&
      freeText == null;

  @override
  String toString() => [
        if (artist != null) 'artist=$artist',
        if (medium != null) 'medium=$medium',
        if (category != null) 'category=$category',
        if (style != null) 'style=$style',
        if (colorHex != null) 'color=$colorHex',
        if (minDimension != null) 'min=$minDimension',
        if (maxDimension != null) 'max=$maxDimension',
        if (latestOnly) 'latest',
        if (freeText != null) 'text=$freeText',
      ].join(' ');
}

/// Local AI features (offline-first):
///  1. Duplicate detection via perceptual hashing.
///  2. Automatic tagging + colour palette extraction.
///  3. Artwork analysis (brightness/contrast/orientation/complexity).
///  4. Natural-language + voice query parsing.
///  5. OCR for certificates.
///
/// A remote provider (Gemini / OpenAI) can be layered on top later; every
/// capability here already works fully offline.
class AiService {
  AiService._();

  static final AiService instance = AiService._();

  // ------------------------------------------------------------- Duplicates --

  /// Scans [painting] against [collection] and returns likely duplicates
  /// (sorted by similarity, filtered by the configured threshold).
  List<DuplicateMatch> findDuplicates(
    Painting painting,
    List<Painting> collection, {
    double threshold = AppConstants.duplicateThreshold,
  }) {
    if (painting.aiHash.isEmpty) return const [];
    final result = <DuplicateMatch>[];
    for (final other in collection) {
      if (other.id == painting.id) continue;
      if (other.aiHash.isEmpty) continue;
      final distance = ImageUtils.hammingDistance(painting.aiHash, other.aiHash);
      final similarity = ImageUtils.similarityFromDistance(distance);
      if (similarity >= threshold) {
        result.add(DuplicateMatch(other, similarity));
      }
    }
    result.sort((a, b) => b.similarity.compareTo(a.similarity));
    return result;
  }

  /// Computes a perceptual hash for a new image file.
  Future<String> hashOfFile(File file) => ImageUtils.perceptualHash(file);

  // --------------------------------------------------------------- Analysis --

  /// Runs the full analysis pipeline over image bytes.
  Future<PaintAnalysis> analyzeImage(Uint8List bytes) async {
    final pixel = ImageUtils.analyzePixelData(bytes);
    final colors = ImageUtils.dominantColors(bytes, count: 6);
    return PaintAnalysis(
      brightness: pixel.brightness,
      contrast: pixel.contrast,
      orientation: pixel.orientation,
      complexity: pixel.complexity,
      dominantColors: colors,
    );
  }

  /// Generates a suggestion tag list from pixel analysis.
  List<String> suggestTags(PaintAnalysis analysis) {
    final tags = <String>[];
    if (analysis.orientation == 'Portrait') tags.add('Portrait orientation');
    if (analysis.orientation == 'Landscape') tags.add('Landscape orientation');
    if (analysis.orientation == 'Square') tags.add('Square format');
    if (analysis.brightness > 0.6) {
      tags.add('Bright');
    } else if (analysis.brightness < 0.35) {
      tags.add('Moody');
    }
    if (analysis.contrast > 0.6) {
      tags.add('High contrast');
    } else if (analysis.contrast < 0.35) {
      tags.add('Soft tones');
    }
    if (analysis.complexity > 0.5) tags.add('Detailed');
    for (final hex in analysis.dominantColors) {
      final name = _colorName(ImageUtils.colorFromHex(hex));
      if (!tags.contains(name)) tags.add(name);
    }
    return tags.take(10).toList();
  }

  static String _colorName(Color c) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.hue; // 0..360
    final s = hsl.saturation;
    final l = hsl.lightness;
    if (s < 0.12) {
      if (l > 0.85) return 'White';
      if (l < 0.2) return 'Black';
      return 'Grey';
    }
    if (l < 0.2) return 'Dark';
    if (h < 18) return 'Red';
    if (h < 42) return 'Orange';
    if (h < 70) return 'Yellow';
    if (h < 165) return 'Green';
    if (h < 200) return 'Teal';
    if (h < 260) return 'Blue';
    if (h < 300) return 'Purple';
    if (h < 345) return 'Magenta';
    return 'Red';
  }

  // ------------------------------------------------------------ Voice/search --

  /// Parses conversational queries such as:
  ///  - "show all oil paintings"
  ///  - "find artworks by Ravi"
  ///  - "open latest upload"
  ///  - "find blue paintings"
  ///  - "show paintings larger than 100 cm"
  SearchQuery parseQuery(String raw, {List<Artist>? artists}) {
    final q = SearchQuery();
    var text = raw.toLowerCase().trim();
    if (text.isEmpty) return q;

    // Artists by known name.
    if (artists != null) {
      for (final artist in artists) {
        if (artist.name.isEmpty) continue;
        if (text.contains(artist.name.toLowerCase())) {
          q.artist = artist.name;
          text = text.replaceAll(artist.name.toLowerCase(), '');
        }
      }
    }
    for (final keyword in ['by artist ', 'artist ', 'by ']) {
      if (text.contains(keyword)) {
        final rest = text.split(keyword).last.trim();
        if (rest.isNotEmpty && !rest.contains('than')) {
          q.artist ??= rest;
          text = text.replaceAll(keyword + rest, '');
        }
      }
    }

    // Latest upload.
    if (text.contains('latest') || text.contains('newest') || text.contains('most recent')) {
      q.latestOnly = true;
    }

    // Dimensions: "larger than 100 cm", "bigger than 200", "smaller than 50".
    final dimReg = RegExp(
      r'(larger|bigger|greater|taller|more than|smaller|less than|under|above|below)\s*(?:than\s*)?(\d+(?:\.\d+)?)\s*(cm|in|mm)?',
    );
    final dimMatch = dimReg.firstMatch(text);
    if (dimMatch != null) {
      final value = double.tryParse(dimMatch.group(2)!) ?? 0;
      final larger = dimMatch.group(1)!.startsWith('larger') ||
          dimMatch.group(1)!.startsWith('bigger') ||
          dimMatch.group(1)!.startsWith('greater') ||
          dimMatch.group(1)!.startsWith('taller') ||
          dimMatch.group(1)!.startsWith('more') ||
          dimMatch.group(1)!.startsWith('above');
      if (larger) {
        q.minDimension = value;
      } else {
        q.maxDimension = value;
      }
    }

    // Colors.
    const colorWords = {
      'red': 'RED', 'orange': 'ORANGE', 'yellow': 'YELLOW', 'green': 'GREEN',
      'blue': 'BLUE', 'purple': 'PURPLE', 'pink': 'MAGENTA', 'black': 'BLACK',
      'white': 'WHITE', 'grey': 'GREY', 'gray': 'GREY', 'brown': 'BROWN',
      'gold': 'GOLD', 'silver': 'SILVER', 'teal': 'TEAL',
    };
    for (final entry in colorWords.entries) {
      if (text.contains(entry.key)) {
        q.colorHex = _hexForName(entry.value);
        break;
      }
    }

    // Medium.
    for (final m in AppConstants.mediums) {
      final key = m.toLowerCase();
      final stem = key.split(' on ').first;
      if (text.contains(stem)) {
        q.medium = m;
        break;
      }
    }
    // Category.
    for (final c in AppConstants.categories) {
      if (text.contains(c.toLowerCase())) {
        q.category = c;
        break;
      }
    }
    // Style.
    for (final s in AppConstants.styles) {
      if (text.contains(s.toLowerCase())) {
        q.style = s;
        break;
      }
    }

    final stop = RegExp(
      r'\b(show|all|find|open|paintings|artworks|art|work|please|me|the|a|an|with|in)\b',
    );
    final leftover = text.replaceAll(stop, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (leftover.isNotEmpty && q.artist == null && q.medium == null) {
      q.freeText = leftover;
    }
    return q;
  }

  static String _hexForName(String name) => switch (name) {
        'RED' => '#EF4444',
        'ORANGE' => '#F97316',
        'YELLOW' => '#FACC15',
        'GREEN' => '#22C55E',
        'BLUE' => '#3B82F6',
        'PURPLE' => '#8B5CF6',
        'MAGENTA' => '#EC4899',
        'BLACK' => '#0F172A',
        'WHITE' => '#F8FAFC',
        'GREY' => '#94A3B8',
        'BROWN' => '#92400E',
        'GOLD' => '#F59E0B',
        'SILVER' => '#CBD5E1',
        'TEAL' => '#14B8A6',
        _ => '#3B82F6',
      };

  /// Filters a painting list by a parsed [SearchQuery].
  List<Painting> applyQuery(List<Painting> all, SearchQuery q) {
    var result = all.where((p) => !p.isDeleted).toList();

    if (q.artist != null) {
      result = result
          .where((p) => p.artistName.toLowerCase().contains(q.artist!.toLowerCase()))
          .toList();
    }
    if (q.medium != null) {
      result = result.where((p) => p.medium.toLowerCase().contains(q.medium!.toLowerCase())).toList();
    }
    if (q.category != null) {
      result = result.where((p) => p.category.toLowerCase() == q.category!.toLowerCase()).toList();
    }
    if (q.style != null) {
      result = result.where((p) => p.style.toLowerCase().contains(q.style!.toLowerCase())).toList();
    }
    if (q.colorHex != null) {
      final target = ImageUtils.colorFromHex(q.colorHex!);
      result = result.where((p) {
        for (final hex in p.dominantColors) {
          if (_colorDistance(target, ImageUtils.colorFromHex(hex)) < 0.18) {
            return true;
          }
        }
        return p.tags.any((t) => _colorName(target).toLowerCase() == t.toLowerCase());
      }).toList();
    }
    if (q.minDimension != null) {
      result = result.where((p) =>
          (p.width ?? 0) >= q.minDimension! || (p.height ?? 0) >= q.minDimension!).toList();
    }
    if (q.maxDimension != null) {
      result = result.where((p) =>
          ((p.width ?? double.infinity) <= q.maxDimension!) &&
          ((p.height ?? double.infinity) <= q.maxDimension!)).toList();
    }
    if (q.latestOnly && result.isNotEmpty) {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      result = [result.first];
    }
    if (q.freeText != null && q.freeText!.isNotEmpty) {
      final terms = q.freeText!.split(' ');
      result = result.where((p) {
        final haystack =
            '${p.title} ${p.description} ${p.tags.join(' ')} ${p.artistName}'.toLowerCase();
        return terms.every((t) => haystack.contains(t));
      }).toList();
    }
    return result;
  }

  static double _colorDistance(Color a, Color b) {
    final dr = a.r - b.r;
    final dg = a.g - b.g;
    final db = a.b - b.b;
    return math.sqrt(dr * dr + dg * dg + db * db) / math.sqrt(3);
  }

  // -------------------------------------------------------------------- OCR --

  /// Extracts raw text from an image using on-device ML Kit.
  ///
  /// A fresh recognizer is created per call so OCR keeps working for the whole
  /// app session (a closed recognizer cannot be reused).
  Future<String> extractText(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(image.path);
      final text = await recognizer.processImage(input);
      return text.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}

/// Immutable result of the AI image analysis pipeline.
class PaintAnalysis {
  final double brightness;
  final double contrast;
  final String orientation;
  final double complexity;
  final List<String> dominantColors;

  const PaintAnalysis({
    required this.brightness,
    required this.contrast,
    required this.orientation,
    required this.complexity,
    required this.dominantColors,
  });

  /// Reads a human-readable style confidence derived from the metrics.
  String get styleGuess {
    if (contrast > 0.62 && complexity > 0.55) return 'Expressive & Detailed';
    if (contrast > 0.62) return 'High Contrast';
    if (brightness > 0.62 && complexity < 0.4) return 'Minimal & Airy';
    if (brightness < 0.4) return 'Dark / Moody';
    return 'Balanced';
  }
}
