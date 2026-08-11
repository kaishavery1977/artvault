import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/painting.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'file_storage_service.dart';

/// Generates PDF / Excel / CSV exports of the collection and prints them.
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  static const PdfColor _accent = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _ink = PdfColor.fromInt(0xFF0F172A);

  // ---------------------------------------------------------------- Catalog --

  /// Builds a print-ready PDF catalogue of the supplied paintings.
  Future<Uint8List> buildCatalogPdf(List<Painting> paintings) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              AppConstants.appName,
              style: pw.TextStyle(
                color: _accent,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Catalogue · ${paintings.length} artworks',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'ArtVault Catalogue',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 26,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          if (paintings.isEmpty)
            pw.Text('No artworks in this selection yet.')
          else
            ..._paintingsToPdf(paintings),
        ],
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _paintingsToPdf(List<Painting> paintings) {
    final rows = <pw.Widget>[];
    for (final painting in paintings) {
      rows.add(_paintingPdfCard(painting));
      rows.add(pw.SizedBox(height: 14));
    }
    return rows;
  }

  pw.Widget _paintingPdfCard(Painting painting) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (painting.coverImagePath.isNotEmpty &&
              File(painting.coverImagePath).existsSync())
            pw.Container(
              width: 72,
              height: 72,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
                image: pw.DecorationImage(
                  image: pw.MemoryImage(
                    File(painting.coverImagePath).readAsBytesSync(),
                  ),
                  fit: pw.BoxFit.cover,
                ),
              ),
            )
          else
            pw.Container(
              width: 72,
              height: 72,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text(
                  'NO IMAGE',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  painting.title,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 14,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  painting.artistName,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${painting.medium} · ${painting.category}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                if (painting.width != null || painting.price != null)
                  pw.Text(
                    '${Formatters.dimensions(width: painting.width, height: painting.height, unit: painting.dimensionUnit)}'
                    '${painting.price != null ? '  ·  ${Formatters.money(painting.price, currency: painting.currency)}' : ''}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prints a PDF via the system print dialog.
  Future<void> printCatalog(List<Painting> paintings) async {
    await Printing.layoutPdf(
      onLayout: (format) async => buildCatalogPdf(paintings),
      name: 'ArtVault Catalog',
    );
  }

  // ------------------------------------------------------------------ Excel --

  Future<File> exportExcel(List<Painting> paintings) async {
    final excel = Excel.createExcel();
    final sheet = excel['Collection'];

    final headers = <String>[
      'Title', 'Artist', 'Category', 'Medium', 'Style', 'Width', 'Height',
      'Depth', 'Unit', 'Price', 'Currency', 'Availability', 'Location',
      'Tags', 'Date Created', 'Created At',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final painting in paintings) {
      sheet.appendRow([
        TextCellValue(painting.title),
        TextCellValue(painting.artistName),
        TextCellValue(painting.category),
        TextCellValue(painting.medium),
        TextCellValue(painting.style),
        if (painting.width != null) DoubleCellValue(painting.width!) else TextCellValue(''),
        if (painting.height != null) DoubleCellValue(painting.height!) else TextCellValue(''),
        if (painting.depth != null) DoubleCellValue(painting.depth!) else TextCellValue(''),
        TextCellValue(painting.dimensionUnit),
        if (painting.price != null) DoubleCellValue(painting.price!) else TextCellValue(''),
        TextCellValue(painting.currency),
        TextCellValue(painting.availability),
        TextCellValue(painting.location),
        TextCellValue(painting.tags.join(', ')),
        TextCellValue(painting.dateCreated ?? ''),
        TextCellValue(Formatters.dateTime(painting.createdAt)),
      ]);
    }

    final bytes = excel.encode() ?? <int>[];
    final file = File(p.join(FileStorageService.instance.exportsDir.path,
        'collection_${Formatters.fileStamp(DateTime.now())}.xlsx'));
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> exportCsv(List<Painting> paintings) async {
    final rows = <List<dynamic>>[
      [
        'Title', 'Artist', 'Category', 'Medium', 'Style', 'Width', 'Height',
        'Depth', 'Unit', 'Price', 'Currency', 'Availability', 'Location',
        'Tags', 'Date Created', 'Created At',
      ],
    ];
    for (final painting in paintings) {
      rows.add([
        painting.title, painting.artistName, painting.category, painting.medium,
        painting.style, painting.width ?? '', painting.height ?? '',
        painting.depth ?? '', painting.dimensionUnit, painting.price ?? '',
        painting.currency, painting.availability, painting.location,
        painting.tags.join('; '), painting.dateCreated ?? '',
        painting.createdAt.toIso8601String(),
      ]);
    }
    final csvString = const CsvEncoder().convert(rows);
    final file = File(p.join(FileStorageService.instance.exportsDir.path,
        'collection_${Formatters.fileStamp(DateTime.now())}.csv'));
    await file.writeAsString(csvString);
    return file;
  }

  /// Single painting PDF (certificate style) used for sharing/printing.
  Future<Uint8List> buildPaintingPdf(Painting painting) async {
    return buildCatalogPdf([painting]);
  }
}
