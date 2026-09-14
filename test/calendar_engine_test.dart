// Task 3G — calendar engine domain tests.
//
// Covers the documented Umm al-Qura conversion method, date normalization,
// date-range expansion, future-date validation, supported boundaries, Hijri
// month lengths, and Gregorian <-> Hijri round trips.

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/calendar/calendar_engine.dart';
import 'package:qaza_namaz/domain/calendar/hijri_date.dart';
import 'package:qaza_namaz/domain/calendar/hijri_ummalqura_calendar.dart';
import 'package:qaza_namaz/domain/calendar/islamic_calendar.dart';

void main() {
  late CalendarEngine engine;

  setUp(() {
    engine = CalendarEngine(now: () => DateTime(2026, 9, 14));
  });

  group('CalendarEngine basics', () {
    test('today is normalized to date-only and matches the injected clock', () {
      expect(engine.today(), DateTime(2026, 9, 14));
    });

    test('normalize strips time-of-day', () {
      expect(
        engine.normalize(DateTime(2026, 9, 14, 23, 59, 59, 999)),
        DateTime(2026, 9, 14),
      );
      expect(
        engine.normalize(DateTime(2024, 2, 29, 3, 0)),
        DateTime(2024, 2, 29),
      );
    });

    test('minAllowedDate is the oldest supported selection', () {
      expect(CalendarEngine.minAllowedDate, DateTime(1950));
      expect(
        CalendarEngine.minAllowedDate.isBefore(
          HijriUmmAlQuraCalendar.earliestSupportedDate,
        ),
        isFalse,
      );
      expect(HijriUmmAlQuraCalendar.earliestSupportedDate, DateTime(1937, 3, 14));
      expect(HijriUmmAlQuraCalendar.latestSupportedDate, DateTime(2077, 11, 16));
    });
  });

  group('Gregorian -> Hijri conversion (Umm al-Qura)', () {
    test('documented anchor dates convert exactly', () {
      // Today (14 Sep 2026) is 3 Rabi' Al-Thani 1448.
      expect(
        engine.gregorianToHijri(DateTime(2026, 9, 14)),
        const HijriDate(year: 1448, month: 4, day: 3),
      );
      // 1 Muharram 1448 AH.
      expect(
        engine.gregorianToHijri(DateTime(2026, 6, 16)),
        const HijriDate(year: 1448, month: 1, day: 1),
      );
      // 1 Ramadan 1440 AH (known Umm al-Qura value).
      expect(
        engine.gregorianToHijri(DateTime(2019, 5, 6)),
        const HijriDate(year: 1440, month: 9, day: 1),
      );
      // 1 Muharram 1438 AH (known Umm al-Qura value).
      expect(
        engine.gregorianToHijri(DateTime(2016, 10, 2)),
        const HijriDate(year: 1438, month: 1, day: 1),
      );
    });

    test('oldest supported boundary is 1 Muharram 1356', () {
      expect(
        engine.gregorianToHijri(
          HijriUmmAlQuraCalendar.earliestSupportedDate,
        ),
        const HijriDate(year: 1356, month: 1, day: 1),
      );
    });

    test('newest supported boundary is 30 Dhu Al-Hijjah 1500', () {
      expect(
        engine.gregorianToHijri(HijriUmmAlQuraCalendar.latestSupportedDate),
        const HijriDate(year: 1500, month: 12, day: 30),
      );
    });

    test('Hijri year boundary around 1 Muharram (Hijri new year) is correct', () {
      // 29 Dhu Al-Hijjah 1447 (last day of 1447) = 15 Jun 2026;
      // the next day is 1 Muharram 1448 (first day of 1448).
      expect(
        engine.gregorianToHijri(DateTime(2026, 6, 15)),
        const HijriDate(year: 1447, month: 12, day: 29),
      );
      expect(
        engine.gregorianToHijri(DateTime(2026, 6, 16)),
        const HijriDate(year: 1448, month: 1, day: 1),
      );
    });

    test('conversion throws RangeError outside the Umm al-Qura window', () {
      expect(
        () => engine.gregorianToHijri(DateTime(1936, 12, 31)),
        throwsRangeError,
      );
      expect(
        () => engine.gregorianToHijri(DateTime(2078, 1, 1)),
        throwsRangeError,
      );
      expect(
        () => engine.hijriToGregorian(
          const HijriDate(year: 1355, month: 12, day: 29),
        ),
        throwsRangeError,
      );
      expect(
        () => engine.hijriToGregorian(
          const HijriDate(year: 1501, month: 1, day: 1),
        ),
        throwsRangeError,
      );
    });
  });

  group('Hijri -> Gregorian conversion', () {
    test('1 Muharram 1448 maps back to 16 Jun 2026', () {
      expect(
        engine.hijriToGregorian(
          const HijriDate(year: 1448, month: 1, day: 1),
        ),
        DateTime(2026, 6, 16),
      );
    });

    test('Hijri month lengths follow the Umm al-Qura table for 1448', () {
      const expected = {
        1: 29, 2: 30, 3: 29, 4: 30, 5: 30, 6: 29,
        7: 30, 8: 30, 9: 29, 10: 30, 11: 29, 12: 30,
      };
      for (final entry in expected.entries) {
        expect(
          engine.islamic.hijriMonthLength(1448, entry.key),
          entry.value,
          reason: '1448 month ${entry.key} length',
        );
      }
    });
  });
group('Round trips (Gregorian -> Hijri -> Gregorian)', () {
    test('conversion is an exact bijection across the supported range', () {
      final samples = [
        DateTime(1950, 1, 1), // oldest selectable
        DateTime(1960, 12, 31),
        DateTime(1975, 6, 15),
        DateTime(1983, 7, 1),
        DateTime(2000, 2, 29), // Gregorian leap day
        DateTime(2001, 1, 1), // Hijri new year (1 Muharram 1421)
        DateTime(2008, 12, 31),
        DateTime(2020, 2, 29), // Gregorian leap day
        DateTime(2023, 12, 31),
        DateTime(2024, 2, 29), // Gregorian leap day
        DateTime(2026, 9, 13), // yesterday
        DateTime(2026, 9, 14), // today
        DateTime(2045, 6, 6),
        DateTime(2077, 11, 16), // newest supported boundary
      ];
      for (final sample in samples) {
        final hijri = engine.gregorianToHijri(sample);
        expect(
          engine.hijriToGregorian(hijri),
          sample,
          reason: 'round trip for $sample',
        );
      }
    });

    test('every calendar day for a full month round-trips uniquely', () {
      // September 2026 spans Rabi' Al-Awwal/Al-Thani 1448 (month boundary).
      for (var day = 1; day <= 30; day++) {
        final gregorian = DateTime(2026, 9, day);
        final hijri = engine.gregorianToHijri(gregorian);
        expect(
          engine.hijriToGregorian(hijri),
          gregorian,
          reason: 'round trip for $gregorian -> $hijri',
        );
      }
    });
  });

  group('Date comparison and future-date protection', () {
    test('today is not future; yesterday and last month are selectable', () {
      expect(engine.isFuture(DateTime(2026, 9, 14)), isFalse);
      expect(engine.isFuture(DateTime(2026, 9, 13)), isFalse);
      expect(engine.isFuture(DateTime(2026, 8, 31)), isFalse);
    });

    test('tomorrow and any later date are future and locked', () {
      expect(engine.isFuture(DateTime(2026, 9, 15)), isTrue);
      expect(engine.isFuture(DateTime(2027, 1, 1)), isTrue);
    });

    test('compareDates orders normalized dates only', () {
      expect(
        engine.compareDates(DateTime(2026, 9, 14, 1), DateTime(2026, 9, 14, 23)),
        0,
      );
      expect(
        engine.compareDates(DateTime(2026, 9, 13), DateTime(2026, 9, 14)),
        isNegative,
      );
      expect(
        engine.compareDates(DateTime(2026, 9, 15), DateTime(2026, 9, 14)),
        isPositive,
      );
    });

    test('isSameDay ignores time components', () {
      expect(
        engine.isSameDay(DateTime(2026, 9, 14, 8), DateTime(2026, 9, 14, 22)),
        isTrue,
      );
      expect(
        engine.isSameDay(DateTime(2026, 9, 14), DateTime(2026, 9, 13)),
        isFalse,
      );
    });

    test('oldest supported minimum boundary detection', () {
      expect(engine.isBeforeMinimum(DateTime(1949, 12, 31)), isTrue);
      expect(engine.isBeforeMinimum(DateTime(1950, 1, 1)), isFalse);
    });
  });
group('Date-range expansion', () {
    test('single-day range expands to exactly one normalized day', () {
      expect(
        engine.expandRange(DateTime(2026, 9, 14), DateTime(2026, 9, 14)),
        [DateTime(2026, 9, 14)],
      );
    });

    test('1 Jan -> 5 Jan produces every day with no gaps or duplicates', () {
      final days = engine.expandRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5));
      expect(days, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
        DateTime(2026, 1, 5),
      ]);
      expect(days.toSet().length, days.length, reason: 'no duplicates');
    });

    test('ranges spanning month boundaries include every day', () {
      final days = engine.expandRange(
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 2),
      );
      expect(days, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 2),
      ]);
    });

    test('ranges spanning Gregorian year boundaries include every day', () {
      final days = engine.expandRange(
        DateTime(2025, 12, 30),
        DateTime(2026, 1, 2),
      );
      expect(days, [
        DateTime(2025, 12, 30),
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
      ]);
    });

    test('Gregorian leap day is included in 2024 ranges and absent in 2023', () {
      final leap = engine.expandRange(DateTime(2024, 2, 27), DateTime(2024, 3, 1));
      expect(leap, [
        DateTime(2024, 2, 27),
        DateTime(2024, 2, 28),
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 1),
      ]);

      final ordinary = engine.expandRange(
        DateTime(2023, 2, 27),
        DateTime(2023, 3, 1),
      );
      expect(ordinary, [
        DateTime(2023, 2, 27),
        DateTime(2023, 2, 28),
        DateTime(2023, 3, 1),
      ]);
    });

    test('start and end values with time components are normalized', () {
      final days = engine.expandRange(
        DateTime(2026, 9, 14, 23, 59),
        DateTime(2026, 9, 16, 0, 1),
      );
      expect(days, [
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 16),
      ]);
    });

    test('reversed ranges throw an informative ArgumentError', () {
      expect(
        () => engine.expandRange(DateTime(2026, 9, 5), DateTime(2026, 9, 1)),
        throwsArgumentError,
      );
    });

    test('daysBetween is inclusive of both ends', () {
      expect(engine.daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 5)), 5);
      expect(engine.daysBetween(DateTime(2026, 9, 14), DateTime(2026, 9, 14)), 1);
    });
  });

  group('dateKey', () {
    test('produces stable zero-padded YYYY-MM-DD keys', () {
      expect(engine.dateKey(DateTime(2026, 9, 14)), '2026-09-14');
      expect(engine.dateKey(DateTime(1950, 1, 1)), '1950-01-01');
    });
  });
group('HijriDate value object', () {
    test('addMonths steps across Hijri month and year boundaries', () {
      const first = HijriDate(year: 1448, month: 1, day: 1);
      expect(first.addMonths(1), const HijriDate(year: 1448, month: 2, day: 1));
      expect(first.addMonths(12), const HijriDate(year: 1449, month: 1, day: 1));
      expect(first.addMonths(-1), const HijriDate(year: 1447, month: 12, day: 1));
      expect(first.addMonths(-13), const HijriDate(year: 1446, month: 12, day: 1));
    });

    test('compareTo matches chronological Hijri ordering', () {
      const a = HijriDate(year: 1447, month: 12, day: 30);
      const b = HijriDate(year: 1448, month: 1, day: 1);
      const c = HijriDate(year: 1448, month: 1, day: 2);
      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(c), isNegative);
      expect(c.compareTo(a), isPositive);
      expect(
        a.compareTo(const HijriDate(year: 1447, month: 12, day: 30)),
        0,
      );
    });

    test('equality and hashCode compare all three fields', () {
      const a = HijriDate(year: 1448, month: 4, day: 3);
      const b = HijriDate(year: 1448, month: 4, day: 3);
      const c = HijriDate(year: 1448, month: 4, day: 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('monthIndex counts whole months from Hijri year 1', () {
      expect(
        const HijriDate(year: 1448, month: 1, day: 1).monthIndex,
        1448 * 12,
      );
      expect(
        const HijriDate(year: 1447, month: 12, day: 1).monthIndex,
        (1447 * 12) + 11,
      );
    });

    test('invalid component values are rejected by constructor asserts', () {
      expect(
        () => HijriDate(year: 0, month: 1, day: 1),
        throwsAssertionError,
      );
      expect(
        () => HijriDate(year: 1448, month: 0, day: 1),
        throwsAssertionError,
      );
      expect(
        () => HijriDate(year: 1448, month: 13, day: 1),
        throwsAssertionError,
      );
      expect(
        () => HijriDate(year: 1448, month: 1, day: 31),
        throwsAssertionError,
      );
    });
  });

  group('Islamic calendar abstraction', () {
    test('engine delegates conversion to the injected implementation', () {
      const hijri = HijriDate(year: 1448, month: 1, day: 1);
      DateTime? capturedInput;
      final stub = _RecordingIslamicCalendar(
        onGregorianToHijri: (DateTime input) {
          capturedInput = input;
          return hijri;
        },
      );
      final stubEngine = CalendarEngine(islamic: stub);
      expect(stubEngine.gregorianToHijri(DateTime(2026, 6, 16)), hijri);
      expect(capturedInput, DateTime(2026, 6, 16));
    });
  });
}

/// Minimal recording stub used to verify the engine talks only to the
/// [IslamicCalendar] contract and never to the concrete package directly.
class _RecordingIslamicCalendar implements IslamicCalendar {
  const _RecordingIslamicCalendar({this.onGregorianToHijri});

  final HijriDate Function(DateTime)? onGregorianToHijri;

  @override
  HijriDate gregorianToHijri(DateTime gregorian) =>
      onGregorianToHijri?.call(gregorian) ??
      const HijriDate(year: 1448, month: 1, day: 1);

  @override
  DateTime hijriToGregorian(HijriDate hijri) => DateTime(2026, 6, 16);

  @override
  int hijriMonthLength(int year, int month) => 30;
}