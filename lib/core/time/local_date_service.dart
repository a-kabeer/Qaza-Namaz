import 'package:timezone/timezone.dart' as tz;

/// Shared Gregorian date-boundary utilities.
///
/// The application's domain uses Gregorian [DateTime] values as canonical
/// dates. These helpers ensure "today" and calendar-day arithmetic are based
/// on the configured device IANA timezone rather than elapsed wall-clock
/// durations around daylight-saving transitions.
class LocalDateService {
  const LocalDateService._();

  /// Returns the current local Gregorian calendar date using [tz.local].
  static DateTime today() {
    final now = tz.TZDateTime.now(tz.local);
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Compares calendar dates by Gregorian year/month/day only.
  static int compareCalendarDates(DateTime a, DateTime b) {
    final left = dateOnly(a);
    final right = dateOnly(b);
    if (left.year != right.year) return left.year.compareTo(right.year);
    if (left.month != right.month) return left.month.compareTo(right.month);
    return left.day.compareTo(right.day);
  }

  /// Returns Gregorian calendar-day distance without DST-related hour loss.
  static int calendarDayDifference(DateTime start, DateTime end) {
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    return endUtc.difference(startUtc).inDays;
  }

  /// Adds whole Gregorian calendar days without allowing DST to change the
  /// resulting calendar date.
  static DateTime addCalendarDays(DateTime date, int days) {
    final utc = DateTime.utc(date.year, date.month, date.day)
        .add(Duration(days: days));
    return DateTime(utc.year, utc.month, utc.day);
  }
}
