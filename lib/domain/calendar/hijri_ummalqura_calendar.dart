import 'package:hijri/hijri_calendar.dart' as hijri_calendar;

import 'hijri_date.dart';
import 'islamic_calendar.dart';

/// Umm al-Qura Hijri conversion for the Qaza Namaz app.
///
/// ## Calculation basis
/// This adapter wraps the mature, pure-Dart `hijri` package (v3, BSD-2). The
/// package's `gregorianToHijri`/`hijriToGregorian` methods implement the Umm
/// al-Qura calendar of Saudi Arabia: a lookup table of *lunation indices*
/// (new-moon MJDN offsets) derived from the official Saudi Umm al-Qura
/// calendar data, with the van Gent CJDN/JDN algorithms used for the
/// Gregorian math on either side. It is the same method used by many Muslim
/// prayer-time applications for a *civil/Hijri-date* display.
///
/// ## Timezone assumption
/// The Hijri day boundary is aligned to the *local Gregorian date* of the
/// device: a Gregorian [DateTime] is converted using only its year/month/day
/// fields, so the displayed Hijri date changes at local midnight, not at
/// sunset. This is the pragmatic choice for a Qaza ledger where each missed
/// day is recorded once and there is no per-city horizon calculation.
///
/// ## Supported range
/// The Umm al-Qura table covers **1356 AH (14 Mar 1937 CE) to 1500 AH
/// (16 Nov 2077 CE)** inclusive. Conversions outside that window throw a
/// [RangeError]. The app itself constrains selectable dates to
/// 1950-01-01 .. today, so the picker always operates inside the table.
///
/// ## Known limitations
/// - Astronomical visibility differences between regions mean the "official"
///   Umm al-Qura table itself differs by a day from other authorities in
///   some months; that is inherent to the source data, not a bug.
/// - Outside the Umm al-Qura window the table has no data, so no
///   mathematical approximation is silently substituted (an explicit error is
///   raised instead).
/// - Date conversion has no dependency on sunrise/sunset times.
class HijriUmmAlQuraCalendar implements IslamicCalendar {
  const HijriUmmAlQuraCalendar();

  /// Earliest Gregorian date covered by the Umm al-Qura table (1 Muharram 1356).
  static final DateTime earliestSupportedDate = DateTime(1937, 3, 14);

  /// Latest Gregorian date covered by the Umm al-Qura table (30 Dhu Al-Hijjah 1500).
  static final DateTime latestSupportedDate = DateTime(2077, 11, 16);

  /// Earliest supported Hijri year (inclusive).
  static const int earliestSupportedHijriYear = 1356;

  /// Latest supported Hijri year (inclusive).
  static const int latestSupportedHijriYear = 1500;

  @override
  HijriDate gregorianToHijri(DateTime gregorian) {
    final g = DateTime(gregorian.year, gregorian.month, gregorian.day);
    if (g.isBefore(earliestSupportedDate) || g.isAfter(latestSupportedDate)) {
      throw RangeError.range(
        g.millisecondsSinceEpoch,
        earliestSupportedDate.millisecondsSinceEpoch,
        latestSupportedDate.millisecondsSinceEpoch,
        'gregorian',
      );
    }
    final result = hijri_calendar.HijriCalendar.fromDate(g);
    return HijriDate(year: result.hYear, month: result.hMonth, day: result.hDay);
  }

  @override
  DateTime hijriToGregorian(HijriDate hijri) {
    if (hijri.year < earliestSupportedHijriYear ||
        hijri.year > latestSupportedHijriYear) {
      throw RangeError.range(
        hijri.year,
        earliestSupportedHijriYear,
        latestSupportedHijriYear,
        'hijri.year',
      );
    }
    final result = hijri_calendar.HijriCalendar();
    final g = result.hijriToGregorian(hijri.year, hijri.month, hijri.day);
    return DateTime(g.year, g.month, g.day);
  }

  @override
  int hijriMonthLength(int year, int month) {
    final result = hijri_calendar.HijriCalendar();
    return result.getDaysInMonth(year, month);
  }
}