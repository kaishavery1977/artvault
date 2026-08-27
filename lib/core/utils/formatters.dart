import 'package:intl/intl.dart';

/// Number / date / text formatting helpers.
abstract final class Formatters {
  static final NumberFormat _money = NumberFormat.currency(
    symbol: '',
    decimalDigits: 0,
  );

  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy · h:mm a');
  static final DateFormat _fileDate = DateFormat('yyyy-MM-dd_HHmm');

  static String money(num? value, {String currency = 'USD'}) {
    if (value == null) return '—';
    final amount = NumberFormat.currency(
      symbol: currencySymbol(currency),
      decimalDigits: 0,
    ).format(value);
    return amount.trim();
  }

  /// Display symbol/prefix for a currency code, e.g. '₹' for INR.
  ///
  /// Currencies without a single well-known glyph (AED, CHF) use the ISO code
  /// as a prefix so the value is never ambiguous.
  static String currencySymbol(String currency) =>
      switch (currency.toUpperCase()) {
        'USD' => '\$',
        'EUR' => '€',
        'GBP' => '£',
        'INR' => '₹',
        'AED' => 'AED ',
        'JPY' => '¥',
        'CHF' => 'CHF ',
        'CAD' => 'C\$',
        'AUD' => 'A\$',
        'SGD' => 'S\$',
        'CNY' => '¥',
        'KRW' => '₩',
        'TRY' => '₺',
        'ZAR' => 'R ',
        'BRL' => 'R\$',
        'MXN' => 'MX\$',
        'RUB' => '₽',
        'SAR' => 'SR ',
        _ => '$currency ',
      };

  static String number(num? value) {
    if (value == null) return '0';
    return _money.format(value).replaceAll(',', ',');
  }

  static String compact(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  static String percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);

  static String fileStamp(DateTime value) => _fileDate.format(value);

  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String dimensions({
    double? width,
    double? height,
    double? depth,
    String? unit,
  }) {
    if (width == null && height == null) return '—';
    final u = (unit ?? 'cm').trim();
    final w = width?.toStringAsFixed(1) ?? '—';
    final h = height?.toStringAsFixed(1) ?? '—';
    if (depth != null) return '$w × $h × ${depth.toStringAsFixed(1)} $u';
    return '$w × $h $u';
  }
}
