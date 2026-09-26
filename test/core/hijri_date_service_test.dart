import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';

void main() {
  const englishMonths = <int, String>{
    1: 'Muharram',
    2: 'Safar',
    3: 'Rabi al-Awwal',
    4: 'Rabi al-Thani',
    5: 'Jumada al-Awwal',
    6: 'Jumada al-Thani',
    7: 'Rajab',
    8: "Sha'ban",
    9: 'Ramadan',
    10: 'Shawwal',
    11: 'Dhu al-Qadah',
    12: 'Dhu al-Hijjah',
  };

  const urduMonths = <int, String>{
    1: 'محرم',
    2: 'صفر',
    3: 'ربیع الاول',
    4: 'ربیع الثانی',
    5: 'جمادی الاول',
    6: 'جمادی الثانی',
    7: 'رجب',
    8: 'شعبان',
    9: 'رمضان',
    10: 'شوال',
    11: 'ذوالقعدہ',
    12: 'ذوالحجہ',
  };

  final en = AppLocalizationsEn();
  final ur = AppLocalizationsUr();

  test('derives Hijri from the Gregorian calendar day only', () {
    final morning = DateTime(2026, 9, 26, 1, 2);
    final evening = DateTime(2026, 9, 26, 23, 59);

    final morningParts = HijriDateService.fromGregorian(morning);
    final eveningParts = HijriDateService.fromGregorian(evening);

    expect(morningParts.day, eveningParts.day);
    expect(morningParts.month, eveningParts.month);
    expect(morningParts.year, eveningParts.year);
    expect(morningParts.month, inInclusiveRange(1, 12));
  });

  test('resolves every Hijri month through localization', () {
    for (var month = 1; month <= 12; month++) {
      expect(
        HijriDateService.monthNameFor(month, en),
        englishMonths[month],
      );
      expect(
        HijriDateService.monthNameFor(month, ur),
        urduMonths[month],
      );
      expect(
        HijriDateService.monthNameFor(month, en),
        isNot(month.toString()),
      );
    }
  });

  test('monthName is derived from the same Gregorian source as format', () {
    final date = DateTime(2026, 9, 26, 14, 30);
    final parts = HijriDateService.fromGregorian(date);

    expect(
      HijriDateService.monthName(date, en),
      HijriDateService.monthNameFor(parts.month, en),
    );
    expect(
      HijriDateService.format(date, en),
      en.hijriDate(
        parts.day,
        HijriDateService.monthNameFor(parts.month, en),
        parts.year,
      ),
    );
  });

  test('Urdu formatting stays localized and uses a named month', () {
    final date = DateTime(2026, 9, 26);
    final parts = HijriDateService.fromGregorian(date);

    expect(
      HijriDateService.format(date, ur),
      ur.hijriDate(
        parts.day,
        HijriDateService.monthNameFor(parts.month, ur),
        parts.year,
      ),
    );
    expect(
      HijriDateService.monthNameFor(parts.month, ur),
      isNot(parts.month.toString()),
    );
  });

  test('feature and application lib code cannot bypass the Hijri boundary', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    const forbiddenMarkers = <String>[
      'package:hijri/',
      'HijriCalendar',
      'hDay',
      'hMonth',
      'hYear',
      'getLongMonthName(',
    ];
    const allowedBoundary = 'lib/core/calendar/hijri_date_service.dart';

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      final normalized = entity.path.replaceAll('\\\\', '/');

      final matches = forbiddenMarkers.where(content.contains).toList();
      if (matches.isEmpty) continue;

      expect(
        normalized,
        allowedBoundary,
        reason:
            'Hijri package/conversion markers are allowed only in the shared calendar layer: $matches',
      );
    }
  });
}
