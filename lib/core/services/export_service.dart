import 'package:artvault/utils/io_shim.dart';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/painting.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'file_storage_service.dart';
import 'qr_service.dart';

/// Generates PDF / Excel / CSV exports of the collection and prints them.
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  static const PdfColor _accent = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _ink = PdfColor.fromInt(0xFF0F172A);

  // ---------------------------------------------------------------- Catalog --

  /// Builds a print-ready PDF catalogue of the supplied paintings.
  Future<Uint8List> buildCatalogPdf(List<Painting> paintings) async {
    // Pre-compute painting widgets outside the synchronous build callback.
    final paintingWidgets = await _paintingsToPdf(paintings);
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
            ...paintingWidgets,
        ],
      ),
    );
    return doc.save();
  }

  Future<List<pw.Widget>> _paintingsToPdf(List<Painting> paintings) async {
    final rows = <pw.Widget>[];
    for (final painting in paintings) {
      rows.add(await _paintingPdfCard(painting));
      rows.add(pw.SizedBox(height: 14));
    }
    return rows;
  }

  Future<pw.Widget> _paintingPdfCard(Painting painting) async {
    pw.MemoryImage? image;
    if (painting.coverImagePath.isNotEmpty) {
      final file = File(painting.coverImagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        image = pw.MemoryImage(bytes);
      }
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (image != null)
            pw.Container(
              width: 72,
              height: 72,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
                image: pw.DecorationImage(image: image, fit: pw.BoxFit.cover),
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
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${painting.medium} · ${painting.category}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                if (painting.width != null || painting.price != null)
                  pw.Text(
                    '${Formatters.dimensions(width: painting.width, height: painting.height, unit: painting.dimensionUnit)}'
                    '${painting.price != null ? '  ·  ${Formatters.money(painting.price, currency: painting.currency)}' : ''}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
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
      'Title',
      'Artist',
      'Category',
      'Medium',
      'Style',
      'Width',
      'Height',
      'Depth',
      'Unit',
      'Price',
      'Currency',
      'Availability',
      'Location',
      'Tags',
      'Date Created',
      'Created At',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final painting in paintings) {
      sheet.appendRow([
        TextCellValue(painting.title),
        TextCellValue(painting.artistName),
        TextCellValue(painting.category),
        TextCellValue(painting.medium),
        TextCellValue(painting.style),
        if (painting.width != null)
          DoubleCellValue(painting.width!)
        else
          TextCellValue(''),
        if (painting.height != null)
          DoubleCellValue(painting.height!)
        else
          TextCellValue(''),
        if (painting.depth != null)
          DoubleCellValue(painting.depth!)
        else
          TextCellValue(''),
        TextCellValue(painting.dimensionUnit),
        if (painting.price != null)
          DoubleCellValue(painting.price!)
        else
          TextCellValue(''),
        TextCellValue(painting.currency),
        TextCellValue(painting.availability),
        TextCellValue(painting.location),
        TextCellValue(painting.tags.join(', ')),
        TextCellValue(painting.dateCreated ?? ''),
        TextCellValue(Formatters.dateTime(painting.createdAt)),
      ]);
    }

    final bytes = excel.encode() ?? <int>[];
    final file = File(
      p.join(
        FileStorageService.instance.exportsDir.path,
        'collection_${Formatters.fileStamp(DateTime.now())}.xlsx',
      ),
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> exportCsv(List<Painting> paintings) async {
    final rows = <List<dynamic>>[
      [
        'Title',
        'Artist',
        'Category',
        'Medium',
        'Style',
        'Width',
        'Height',
        'Depth',
        'Unit',
        'Price',
        'Currency',
        'Availability',
        'Location',
        'Tags',
        'Date Created',
        'Created At',
      ],
    ];
    for (final painting in paintings) {
      rows.add([
        painting.title,
        painting.artistName,
        painting.category,
        painting.medium,
        painting.style,
        painting.width ?? '',
        painting.height ?? '',
        painting.depth ?? '',
        painting.dimensionUnit,
        painting.price ?? '',
        painting.currency,
        painting.availability,
        painting.location,
        painting.tags.join('; '),
        painting.dateCreated ?? '',
        painting.createdAt.toIso8601String(),
      ]);
    }
    final csvString = const CsvEncoder().convert(rows);
    final file = File(
      p.join(
        FileStorageService.instance.exportsDir.path,
        'collection_${Formatters.fileStamp(DateTime.now())}.csv',
      ),
    );
    await file.writeAsString(csvString);
    return file;
  }

  /// Single painting PDF (certificate style) used for sharing/printing.
  Future<Uint8List> buildPaintingPdf(Painting painting) async {
    return buildCatalogPdf([painting]);
  }

  // ------------------------------------------------- Insurance schedule --

  /// A one-tap insurance schedule: a table of every artwork with its insured
  /// value (currency-aware), dimensions and location, plus a grand total.
  /// Replaces the schedule you'd otherwise type by hand for an insurer.
  Future<Uint8List> buildInsuranceSchedulePdf(List<Painting> paintings) async {
    final doc = pw.Document();
    final valued = paintings.where((p) => p.price != null).toList();
    final totalByCurrency = <String, double>{};
    for (final p in valued) {
      final code = p.currency.isEmpty ? 'USD' : p.currency;
      totalByCurrency[code] = (totalByCurrency[code] ?? 0) + (p.price ?? 0);
    }

    pw.Widget totalRow() {
      final parts = totalByCurrency.entries
          .map((e) => _asciiMoney(e.value, e.key))
          .join(' + ');
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 14),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL INSURED VALUE',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.Text(
              parts.isEmpty ? '-' : parts,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _accent,
              ),
            ),
          ],
        ),
      );
    }

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
              'Insurance schedule | ${paintings.length} artworks',
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
            'Insurance Schedule',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 24,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'For insurance / valuation purposes · Generated '
            '${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerCount: 1,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _accent),
            headers: ['Artwork', 'Artist', 'Dimensions', 'Location', 'Value'],
            data: paintings
                .map(
                  (p) => [
                    p.title,
                    p.artistName.isEmpty ? '-' : p.artistName,
                    p.width == null ? '-' : _asciiDimensions(p),
                    p.location.isEmpty ? '-' : p.location,
                    p.price == null ? '-' : _asciiMoney(p.price!, p.currency),
                  ],
                )
                .toList(),
          ),
          totalRow(),
        ],
      ),
    );
    return doc.save();
  }

  /// Currency amount as ASCII for PDFs: grouped number + ISO code, e.g.
  /// "12,500 USD". The pdf package's built-in Helvetica has no Unicode
  /// glyphs (€, £…), so the symbol-bearing [Formatters.money] would render
  /// blanks on paper.
  static String _asciiMoney(double value, String currency) {
    final code = currency.isEmpty ? 'USD' : currency.toUpperCase();
    final amount = NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
    ).format(value);
    return '$amount $code'.trim();
  }

  static String _asciiDimensions(Painting p) {
    final u = (p.dimensionUnit.isEmpty ? 'cm' : p.dimensionUnit).trim();
    final w = p.width?.toStringAsFixed(1) ?? '-';
    final h = p.height?.toStringAsFixed(1) ?? '-';
    final depth = p.depth;
    if (depth != null) return '$w x $h x ${depth.toStringAsFixed(1)} $u';
    return '$w x $h $u';
  }

  // ----------------------------------------------------- QR label sheet --

  /// Printable QR inventory labels: one code per artwork, carrying the
  /// canonical ArtVault payload so scanning any printed label opens that
  /// artwork on any device (locate + verify). Each label shows the code,
  /// title, artist and location. 6 labels per A4 page.
  Future<Uint8List> buildQrLabelSheetPdf(List<Painting> paintings) async {
    final doc = pw.Document();

    pw.Widget label(Painting p) {
      final location = p.location.isEmpty ? '-' : p.location;
      return pw.SizedBox(
        width: 255,
        height: 175,
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: QrService.payloadFor(
                  p.id,
                  title: p.title,
                  artistName: p.artistName,
                  price: p.price,
                  currency: p.currency,
                  description: p.description,
                  imageUrl: p.coverImageUrl,
                ),
                width: 110,
                height: 110,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                p.title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (p.artistName.isNotEmpty)
                pw.Text(
                  p.artistName,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'LOCATION: $location',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <pw.Widget>[];
    for (var i = 0; i < paintings.length; i += 2) {
      rows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            label(paintings[i]),
            if (i + 1 < paintings.length) label(paintings[i + 1]),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => rows.isEmpty
            ? [pw.Text('No artworks to print labels for yet.')]
            : rows,
      ),
    );
    return doc.save();
  }
}
