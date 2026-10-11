import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' as date_symbols;
import 'package:intl/intl.dart' as intl;

import 'package:qaza_namaz/core/utils/date_formatters.dart';

void main() {
  String? originalLocale;

  setUpAll(() async {
    await date_symbols.initializeDateFormatting('ur');
  });

  setUp(() {
    originalLocale = intl.Intl.defaultLocale;
  });

  tearDown(() {
    intl.Intl.defaultLocale = originalLocale;
  });

  group('DateFormatters locale-aware Gregorian dates', () {
    final date = DateTime(2026, 10, 11);

    test('preserves the English date and time presentation', () {
      intl.Intl.defaultLocale = 'en';

      expect(DateFormatters.formatGregorianFull(date), '11 October 2026');
      expect(DateFormatters.formatGregorianDatePadded(date), '11 Oct 2026');
      expect(
        DateFormatters.formatGregorianWeekdayShortFull(date),
        'Sun, Oct 11, 2026',
      );
      expect(
        DateFormatters.formatClockTime(DateTime(2026, 10, 11, 16, 5)),
        '04:05 PM',
      );
    });

    test('uses Urdu month, weekday, and day-period text for Urdu locale', () {
      intl.Intl.defaultLocale = 'ur';
      final urduScript = RegExp(r'[\u0600-\u06FF]');

      expect(DateFormatters.formatGregorianFull(date), matches(urduScript));
      expect(
          DateFormatters.formatGregorianDatePadded(date), matches(urduScript));
      expect(
        DateFormatters.formatGregorianWeekdayShortFull(date),
        matches(urduScript),
      );
      expect(DateFormatters.formatWeekdayShort(date), matches(urduScript));
      expect(
        DateFormatters.formatClockTime(DateTime(2026, 10, 11, 16, 5)),
        matches(urduScript),
      );
    });
  });
}
