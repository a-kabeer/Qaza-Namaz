import '../../core/calendar/hijri_date_service.dart';
import '../../core/time/local_date_service.dart';

/// Fixed arithmetic used only for birth-based Qaza planning.
///
/// The real Hijri calendar remains owned by [HijriDateService]. This service
/// treats the Hijri components returned by that boundary as a numeric input
/// space where every month has exactly 30 arithmetic days and every year has
/// exactly 360 arithmetic days.
class FixedHijriArithmeticService {
  const FixedHijriArithmeticService._();

  static const int daysPerMonth = 30;
  static const int daysPerYear = 360;
  static const int monthsPerYear = 12;

  static int dayIndex({
    required int year,
    required int month,
    required int day,
  }) {
    if (month < 1 || month > monthsPerYear) {
      throw ArgumentError.value(month, 'month', 'Hijri month must be 1-12.');
    }
    if (day < 1 || day > daysPerMonth) {
      throw ArgumentError.value(
        day,
        'day',
        'Fixed Hijri arithmetic day must be 1-30.',
      );
    }
    return year * daysPerYear +
        (month - 1) * daysPerMonth +
        (day - 1);
  }

  static int dayIndexOf(HijriDateParts date) => dayIndex(
        year: date.year,
        month: date.month,
        day: date.day,
      );

  /// Converts a Gregorian date to its real Hijri components at the calendar
  /// boundary, then maps those components into the fixed arithmetic index.
  static int dayIndexForGregorian(DateTime date) =>
      dayIndexOf(HijriDateService.fromGregorian(date));

  /// Returns elapsed fixed-arithmetic days between two Gregorian dates.
  static int elapsedDaysBetween(
    DateTime start,
    DateTime end,
  ) =>
      dayIndexForGregorian(end) - dayIndexForGregorian(start);

  /// Returns fixed-arithmetic duration for integer age inputs.
  static int durationForAges({
    required int pubertyAge,
    required int startPrayingAge,
  }) {
    final duration =
        (startPrayingAge - pubertyAge) * daysPerYear;
    if (duration < 0) {
      throw ArgumentError(
        'startPrayingAge must be greater than or equal to pubertyAge.',
      );
    }
    return duration;
  }

  /// Decomposes a non-negative fixed duration into years, months, and days.
  static FixedHijriDuration splitElapsedDays(int days) {
    if (days < 0) {
      throw ArgumentError.value(days, 'days', 'Must be non-negative.');
    }

    final years = days ~/ daysPerYear;
    final afterYears = days % daysPerYear;
    final months = afterYears ~/ daysPerMonth;
    final remainingDays = afterYears % daysPerMonth;

    return FixedHijriDuration(
      years: years,
      months: months,
      remainingDays: remainingDays,
    );
  }

  /// Returns completed age using the fixed Hijri arithmetic day index.
  ///
  /// This intentionally does not perform Hijri anniversary matching,
  /// target-month clamping, or real 29/30-day month calculations.
  static int currentAge(DateTime dob, DateTime today) {
    final elapsed = elapsedDaysBetween(dob, today);
    if (elapsed >= 0) return elapsed ~/ daysPerYear;
    return -((-elapsed + daysPerYear - 1) ~/ daysPerYear);
  }

  /// Materializes a fixed arithmetic milestone as a canonical Gregorian date.
  ///
  /// The Gregorian DOB is the anchor and the fixed arithmetic offset is
  /// projected deterministically as the same number of Gregorian calendar
  /// days. The resulting date is a ledger boundary, not a claim about an
  /// actual Hijri calendar anniversary.
  static DateTime projectFromBirth({
    required DateTime dob,
    required int fixedDayOffset,
  }) {
    if (fixedDayOffset < 0) {
      throw ArgumentError.value(
        fixedDayOffset,
        'fixedDayOffset',
        'Must be non-negative.',
      );
    }

    // Keep Gregorian ↔ Hijri conversion explicitly at the existing boundary.
    // The arithmetic projection itself never consults real Hijri month lengths.
    HijriDateService.fromGregorian(dob);

    return LocalDateService.addCalendarDays(
      LocalDateService.dateOnly(dob),
      fixedDayOffset,
    );
  }
}

class FixedHijriDuration {
  const FixedHijriDuration({
    required this.years,
    required this.months,
    required this.remainingDays,
  });

  final int years;
  final int months;
  final int remainingDays;

  int get totalDays =>
      years * FixedHijriArithmeticService.daysPerYear +
      months * FixedHijriArithmeticService.daysPerMonth +
      remainingDays;
}
