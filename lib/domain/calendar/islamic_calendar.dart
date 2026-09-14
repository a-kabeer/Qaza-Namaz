import 'hijri_date.dart';

/// Contract for converting between the Gregorian and Hijri calendars.
///
/// The concrete conversion algorithm is deliberately isolated behind this
/// interface so the UI and the [CalendarEngine] never depend on one specific
/// Islamic calendar implementation. Swapping the selected method (for example
/// Umm al-Qura vs a tabular Islamic calendar) is a single-constructor change.
abstract interface class IslamicCalendar {
  /// Converts a Gregorian date to a Hijri date.
  ///
  /// The input is expected to already be date-only (time-free). Throws a
  /// [RangeError] when the date is outside the implementation's supported
  /// lookup range.
  HijriDate gregorianToHijri(DateTime gregorian);

  /// Converts a Hijri date to the corresponding Gregorian date.
  ///
  /// The returned value is date-only (time-free).
  DateTime hijriToGregorian(HijriDate hijri);

  /// Number of days in the given Hijri month (28-30 for Umm al-Qura).
  int hijriMonthLength(int year, int month);
}