import 'package:hijri/hijri_calendar.dart';

import '../../l10n/app_localizations.dart';

/// Canonical boundary for all Gregorian ↔ Hijri conversion and presentation.
///
/// Gregorian [DateTime] values remain the application's source of truth.
/// Hijri values are derived on demand and are never exposed as package types.
class HijriDateParts {
  const HijriDateParts({
    required this.day,
    required this.month,
    required this.year,
  });

  final int day;
  final int month;
  final int year;
}

class HijriDateService {
  const HijriDateService._();

  /// Derives Hijri parts from the Gregorian calendar day represented by [date].
  ///
  /// Time-of-day and timezone metadata are intentionally discarded so a
  /// date-only value cannot cross a day boundary during conversion.
  static HijriDateParts fromGregorian(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final hijri = HijriCalendar.fromDate(normalized);
    return HijriDateParts(
      day: hijri.hDay,
      month: hijri.hMonth,
      year: hijri.hYear,
    );
  }

  /// Converts a Hijri date to a date-only Gregorian [DateTime].
  static DateTime toGregorian({
    required int year,
    required int month,
    required int day,
  }) {
    final gregorian = HijriCalendar().hijriToGregorian(year, month, day);
    return DateTime(gregorian.year, gregorian.month, gregorian.day);
  }

  /// Returns the number of days in a Hijri month according to the active
  /// calendar engine/convention.
  static int daysInMonth({
    required int year,
    required int month,
  }) =>
      HijriCalendar().getDaysInMonth(year, month);

  /// Adds whole Hijri calendar years to a Gregorian date.
  ///
  /// The source Gregorian date is first converted to its Hijri date. The
  /// target Hijri year keeps the same month/day, clamping the day to the
  /// target month's actual length when necessary, and is then converted back
  /// to Gregorian.
  static DateTime addHijriYears(DateTime date, int years) {
    if (years < 0) {
      throw ArgumentError.value(years, 'years', 'Must be non-negative.');
    }

    final source = fromGregorian(date);
    final targetYear = source.year + years;
    final targetDay = source.day
        .clamp(1, daysInMonth(year: targetYear, month: source.month))
        .toInt();

    return toGregorian(
      year: targetYear,
      month: source.month,
      day: targetDay,
    );
  }

  /// Returns the localized Hijri month name for [date].
  static String monthName(
    DateTime date,
    AppLocalizations l10n,
  ) =>
      monthNameFor(fromGregorian(date).month, l10n);

  /// Resolves a numeric Hijri month to its localized user-facing name.
  ///
  /// Numeric month values are an internal representation only.
  static String monthNameFor(
    int month,
    AppLocalizations l10n,
  ) {
    return switch (month) {
      1 => l10n.hijriMonthMuharram,
      2 => l10n.hijriMonthSafar,
      3 => l10n.hijriMonthRabiAlAwwal,
      4 => l10n.hijriMonthRabiAlThani,
      5 => l10n.hijriMonthJumadaAlAwwal,
      6 => l10n.hijriMonthJumadaAlThani,
      7 => l10n.hijriMonthRajab,
      8 => l10n.hijriMonthShaban,
      9 => l10n.hijriMonthRamadan,
      10 => l10n.hijriMonthShawwal,
      11 => l10n.hijriMonthDhulQadah,
      12 => l10n.hijriMonthDhulHijjah,
      _ => throw ArgumentError.value(month, 'month', 'Hijri month must be 1-12.'),
    };
  }

  /// Formats a Gregorian month as a localized Hijri month/year label.
  ///
  /// Gregorian months can span two Hijri months. In that case the complete
  /// month/year range is shown rather than presenting the first Gregorian
  /// day's Hijri date as the month header.
  static String monthYearLabel(
    DateTime date,
    AppLocalizations l10n,
  ) {
    final first = fromGregorian(DateTime(date.year, date.month, 1));
    final last = fromGregorian(DateTime(date.year, date.month + 1, 0));

    final firstLabel = l10n.hijriMonthYear(
      monthNameFor(first.month, l10n),
      first.year,
    );
    final lastLabel = l10n.hijriMonthYear(
      monthNameFor(last.month, l10n),
      last.year,
    );

    if (first.month == last.month && first.year == last.year) {
      return firstLabel;
    }

    return l10n.qazaDateFilterRange(
      firstLabel,
      lastLabel,
    );
  }

  /// Formats a Gregorian date as the app's standard secondary Hijri label.
  static String format(
    DateTime date,
    AppLocalizations l10n,
  ) {
    final hijri = fromGregorian(date);
    return l10n.hijriDate(
      hijri.day,
      monthNameFor(hijri.month, l10n),
      hijri.year,
    );
  }
}

/// Convenience API for localized UI code.
///
/// Feature code supplies only its Gregorian [DateTime]; localization remains
/// attached to the already-available AppLocalizations instance.
extension AppLocalizationsHijriDateFormatting on AppLocalizations {
  String formatHijriDate(DateTime date) => HijriDateService.format(date, this);
}
