import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/painting.dart';
import '../constants/app_constants.dart';
import 'file_storage_service.dart';
import 'qr_service.dart';

/// Native social sharing (Instagram, WhatsApp, AirDrop, …) plus watermark
/// composition and QR-code image generation.
class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  /// Renders a QR PNG for [painting], with a white quiet zone so scanners
  /// (including other phones) can decode it reliably.
  Future<Uint8List> qrPng(Painting painting, {int size = 512}) async {
    final painter = QrPainter(
      data: QrService.payloadFor(
        painting.id,
        title: painting.title,
        artistName: painting.artistName,
        price: painting.price,
        currency: painting.currency,
        description: painting.description,
        imageUrl: painting.coverImageUrl,
      ),
      version: QrVersions.auto,
      gapless: true,
      // A null eyeStyle color crashes QrPainter (qr_flutter 4.1.0 default
      // `color` is null) — always pass an explicit color.
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF0F172A),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0F172A),
      ),
    );

    const margin = 32.0;
    final total = (size + margin * 2).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, total.toDouble(), total.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.save();
    canvas.translate(margin, margin);
    painter.paint(canvas, Size(size.toDouble(), size.toDouble()));
    canvas.restore();
    final image = await recorder.endRecording().toImage(total, total);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<void> _share({
    required String text,
    Uint8List? imageBytes,
    List<String>? files,
  }) async {
    var params = ShareParams(
      text: text,
      subject: AppConstants.appName,
      title: AppConstants.appName,
    );
    if (files != null && files.isNotEmpty) {
      params = ShareParams(
        text: text,
        subject: AppConstants.appName,
        title: AppConstants.appName,
        files: [for (final f in files) XFile(f)],
      );
    } else if (imageBytes != null) {
      final dir = FileStorageService.instance.exportsDir;
      final file = File(
        p.join(dir.path, 'share_${DateTime.now().millisecondsSinceEpoch}.png'),
      );
      await file.writeAsBytes(imageBytes);
      params = ShareParams(
        text: text,
        subject: AppConstants.appName,
        title: AppConstants.appName,
        files: [XFile(file.path)],
      );
    }
    await SharePlus.instance.share(params);
  }

  /// Share a painting as plain image.
  Future<void> shareImage(Painting painting, {String? imagePath}) async {
    final path = imagePath ?? painting.coverImagePath;
    if (path.isEmpty || !File(path).existsSync()) {
      await _share(text: _caption(painting));
      return;
    }
    await _share(text: _caption(painting), files: [path]);
  }

  /// Share image + full description text. Defaults to the cover image so
  /// "Image + text" from the share sheet actually attaches the artwork.
  Future<void> shareWithDescription(
    Painting painting, {
    String? imagePath,
  }) async {
    final path = imagePath ?? painting.coverImagePath;
    final hasImage = path.isNotEmpty && File(path).existsSync();
    final desc = painting.description.isNotEmpty
        ? '\n\n${painting.description}'
        : '';
    await _share(
      text: _caption(painting) + desc,
      files: hasImage ? [path] : null,
    );
  }

  /// Composes a watermarked copy of the artwork (brand + title bar) and
  /// shares it through the native sheet — ideal for social posts.
  Future<Uint8List> watermarkedPng(
    Painting painting, {
    String? imagePath,
  }) async {
    final path = imagePath ?? painting.coverImagePath;
    if (path.isEmpty || !File(path).existsSync()) return Uint8List(0);
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return Uint8List(0);

    final font = img.arial24;
    final text = '${AppConstants.appName} - ${painting.title}';
    final barH = font.lineHeight + 20;

    img.fillRect(
      decoded,
      x1: 0,
      y1: (decoded.height - barH).clamp(0, decoded.height),
      x2: decoded.width - 1,
      y2: decoded.height - 1,
      color: img.ColorRgba8(0, 0, 0, 150),
    );
    final textWidth = _textWidth(font, text);
    img.drawString(
      decoded,
      text,
      font: font,
      x: ((decoded.width - textWidth) ~/ 2).clamp(0, decoded.width),
      y: decoded.height - barH + ((barH - font.lineHeight) ~/ 2),
      color: img.ColorRgb8(255, 255, 255),
    );
    return img.encodeJpg(decoded, quality: 92);
  }

  Future<void> shareWatermarked(Painting painting, {String? imagePath}) async {
    final png = await watermarkedPng(painting, imagePath: imagePath);
    if (png.isEmpty) {
      await _share(text: _caption(painting));
      return;
    }
    await _share(text: _caption(painting), imageBytes: png);
  }

  /// Share a QR code image for the painting.
  Future<void> shareQr(Painting painting) async {
    final png = await qrPng(painting);
    await _share(
      text: 'Scan to view "${painting.title}" in ArtVault',
      imageBytes: png,
    );
  }

  /// Share a generated PDF.
  Future<void> sharePdf(Uint8List bytes, String filename) async {
    final dir = FileStorageService.instance.exportsDir;
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);
    await _share(
      text: '${AppConstants.appName} — ${filename.split('.').first}',
      files: [file.path],
    );
  }

  /// Share a file (documents, exports).
  /// Shares plain text (e.g. a public gallery link).
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject ?? AppConstants.appName,
        title: AppConstants.appName,
      ),
    );
  }

  Future<void> shareFile(String path, {String? text}) async {
    await _share(text: text ?? AppConstants.appName, files: [path]);
  }

  String _caption(Painting painting) {
    final parts = <String>[
      painting.title,
      if (painting.artistName.isNotEmpty) 'by ${painting.artistName}',
      if (painting.medium.isNotEmpty) painting.medium,
      if (painting.category.isNotEmpty) painting.category,
    ];
    return '${parts.join(' - ')}\nStored in ${AppConstants.appName}';
  }
}

/// Measures the pixel width of [text] rendered with [font] by summing the
/// advance widths of each glyph (the `image` package exposes no helper).
int _textWidth(img.BitmapFont font, String text) {
  var width = 0;
  for (final code in text.codeUnits) {
    final glyph = font.characters[code];
    width += glyph?.xAdvance ?? font.lineHeight;
  }
  return width;
}
