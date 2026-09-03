import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/utils/formatters.dart';
import 'package:artvault/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email accepts well-formed addresses and rejects bad ones', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('a.b+c-d@sub.domain.co'), isNull);
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('   '), 'Email is required');
      expect(Validators.email('not-an-email'), 'Enter a valid email address');
      expect(Validators.email('a@b'), 'Enter a valid email address');
      expect(Validators.email('a b@c.com'), 'Enter a valid email address');
    });

    test('email caps length at 254', () {
      final long = '${'a' * 250}@example.com'; // 262 chars
      expect(long.length, greaterThan(254));
      expect(Validators.email(long), 'Email must be at most 254 characters');
    });

    test('password enforces min and max lengths', () {
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password('1234567'), 'Password must be at least 8 characters');
      expect(Validators.password('12345678'), isNull);
      expect(
        Validators.password('x' * 129),
        'Password must be at most 128 characters',
      );
    });

    test('passwordConfirm compares against the reference password', () {
      expect(Validators.passwordConfirm('', 'secret1'), 'Confirm your password');
      expect(Validators.passwordConfirm(null, 'secret1'), 'Confirm your password');
      expect(
        Validators.passwordConfirm('secret2', 'secret1'),
        'Passwords do not match',
      );
      expect(Validators.passwordConfirm('secret1', 'secret1'), isNull);
    });

    test('required and name validate presence and length', () {
      expect(Validators.required(null), 'This field is required');
      expect(Validators.required('  '), 'This field is required');
      expect(Validators.required('ok'), isNull);
      expect(
        Validators.required('', message: 'Custom'),
        'Custom',
      );
      expect(Validators.name(''), 'Name is required');
      expect(Validators.name('A'), 'Name is too short');
      expect(Validators.name('Ada'), isNull);
    });

    test('positiveNumber accepts empty/positive and rejects negative or junk', () {
      expect(Validators.positiveNumber(''), isNull);
      expect(Validators.positiveNumber('0'), isNull);
      expect(Validators.positiveNumber('12.5'), isNull);
      expect(Validators.positiveNumber('-3'), 'Enter a positive number');
      expect(Validators.positiveNumber('abc'), 'Enter a positive number');
      expect(
        Validators.positiveNumber('-1', message: 'No negatives'),
        'No negatives',
      );
    });

    test('url accepts absolute URLs and rejects scheme-less text', () {
      expect(Validators.url(''), isNull);
      expect(Validators.url('https://artvault.web.app'), isNull);
      expect(Validators.url('http://localhost:3000/x'), isNull);
      expect(Validators.url('just words'), 'Enter a valid URL');
    });

    test('phone accepts empty and sane lengths, rejects extremes', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('+15550100'), isNull);
      expect(Validators.phone('123'), 'Enter a valid phone number');
      expect(Validators.phone('1' * 16), 'Enter a valid phone number');
    });
  });

  group('Formatters', () {
    test('money handles null and known currency symbols', () {
      expect(Formatters.money(null), '—');
      final usd = Formatters.money(1200000);
      expect(usd, startsWith(r'$'));
      expect(usd.contains('1,200,000'), isTrue);
      expect(Formatters.money(500, currency: 'INR'), startsWith('₹'));
      expect(Formatters.money(700, currency: 'inr'), startsWith('₹')); // case-insensitive
      expect(Formatters.money(100, currency: 'AED'), contains('AED'));
      expect(Formatters.money(100, currency: 'CHF'), contains('CHF'));
      expect(Formatters.money(100, currency: 'XYZ'), contains('XYZ'));
    });

    test('currencySymbol maps known codes and falls back to the code', () {
      expect(Formatters.currencySymbol('USD'), r'$');
      expect(Formatters.currencySymbol('EUR'), '€');
      expect(Formatters.currencySymbol('GBP'), '£');
      expect(Formatters.currencySymbol('JPY'), '¥');
      expect(Formatters.currencySymbol('KRW'), '₩');
      expect(Formatters.currencySymbol('AED'), 'AED ');
      expect(Formatters.currencySymbol('USD'), Formatters.currencySymbol('usd'));
      expect(Formatters.currencySymbol('NOK'), 'NOK ');
    });

    test('compact shortens large numbers', () {
      expect(Formatters.compact(999), '999');
      expect(Formatters.compact(1500), '1.5K');
      expect(Formatters.compact(2500000), '2.5M');
      expect(Formatters.compact(0), '0');
    });

    test('percent and number helpers', () {
      expect(Formatters.percent(0.1234), '12.3%');
      expect(Formatters.percent(1), '100.0%');
      expect(Formatters.number(null), '0');
    });

    test('date helpers format and handle null', () {
      final d = DateTime(2026, 9, 3, 14, 5);
      expect(Formatters.date(null), '—');
      expect(Formatters.date(d), 'Sep 3, 2026');
      expect(Formatters.dateTime(null), '—');
      expect(Formatters.dateTime(d), contains('Sep 3, 2026'));
      expect(Formatters.fileStamp(d), '2026-09-03_1405');
    });

    test('bytes formats each scale boundary', () {
      expect(Formatters.bytes(0), '0 B');
      expect(Formatters.bytes(500), '500 B');
      expect(Formatters.bytes(2048), '2.0 KB');
      expect(Formatters.bytes(5 * 1024 * 1024), '5.0 MB');
      expect(Formatters.bytes(2 * 1024 * 1024 * 1024), '2.00 GB');
    });

    test('initials handles single, multi and empty names', () {
      expect(Formatters.initials(''), '?');
      expect(Formatters.initials('Picasso'), 'P');
      expect(Formatters.initials('Ada Lovelace'), 'AL');
      expect(Formatters.initials('  spaced   name  '), 'SN');
    });

    test('dimensions formats with or without depth and units', () {
      expect(Formatters.dimensions(), '—');
      expect(Formatters.dimensions(width: 12.0, height: 5.0), '12.0 × 5.0 cm');
      expect(
        Formatters.dimensions(width: 12.0, height: 5.0, depth: 2.5),
        '12.0 × 5.0 × 2.5 cm',
      );
      expect(
        Formatters.dimensions(width: 12, height: 5, unit: 'in'),
        '12.0 × 5.0 in',
      );
      expect(Formatters.dimensions(height: 5.0), '— × 5.0 cm');
    });
  });
}
