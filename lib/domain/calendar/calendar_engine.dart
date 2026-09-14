import 'hijri_date.dart';
import 'hijri_ummalqura_calendar.dart';
import 'islamic_calendar.dart';

/// The application's central calendar service.
///
/// Every calendar operation in the app goes through this single abstraction:
///
/// - Gregorian -> Hijri and Hijri -> Gregorian conversion
/// - today / current Hijri date
/// - date normalization (stripping time of day)
/// - date comparison
/// - inclusive date-range expansion
/// - future-date validation
///
/// The canonical Gregorian date is always the source of truth for Qaza
/// records; Hijri values are derived views. The conversion method lives in an
/// [IslamicCalendar] implementation injected at construction time (defaults to
/// the documented [HijriUmmAlQuraCalendar]) so it can be changed centrally
/// without touching any widget.
class CalendarEngine {
  CalendarEngine({IslamicCalendar? islamic, DateTime Function()? now})
      : islamic = islamic ?? const HijriUmmAlQuraCalendar(),
        _now = now ?? DateTime.now;

  /// The active Hijri conversion method.
  final IslamicCalendar islamic;

  /// Clock used to answer "today". Injectable for deterministic tests.
  final DateTime Function() _now;

  /// Earliest selectable/recordable Gregorian date in the app.
  static final DateTime minAllowedDate = DateTime(1950);

  /// The current local date with the time part removed.
  DateTime today() => normalize(_now());

  /// The Hijri date for [today] under the configured conversion method.
  HijriDate todayHijri() => islamic.gregorianToHijri(today());

  /// Drops the time-of-day component, returning a date at local midnight.
  DateTime normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Converts a Gregorian date to its Hijri equivalent.
  HijriDate gregorianToHijri(DateTime gregorian) =>
      islamic.gregorianToHijri(normalize(gregorian));

  /// Converts a Hijri date to its canonical Gregorian equivalent (date-only).
  DateTime hijriToGregorian(HijriDate hijri) =>
      normalize(islamic.hijriToGregorian(hijri));

  /// True when [date] is strictly after today (never recordable as Qaza).
  bool isFuture(DateTime date) => normalize(date).isAfter(today());

  /// True when [date] is earlier than the app's oldest selectable date.
  bool isBeforeMinimum(DateTime date) =>
      normalize(date).isBefore(minAllowedDate);

  /// Orders two dates chronologically using only their calendar day.
  int compareDates(DateTime a, DateTime b) =>
      normalize(a).compareTo(normalize(b));

  /// True when both dates fall on the same calendar day.
  bool isSameDay(DateTime a, DateTime b) {
    final left = normalize(a);
    final right = normalize(b);
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  /// Expands the inclusive range `[start, end]` into every day in between,
  /// with no skipped and no duplicated days.
  ///
  /// Throws an [ArgumentError] when [end] precedes [start] so reversed or
  /// malformed ranges fail loudly instead of producing an empty/odd result.
  List<DateTime> expandRange(DateTime start, DateTime end) {
    final first = normalize(start);
    final last = normalize(end);
    if (last.isBefore(first)) {
      throw ArgumentError(
        'expandRange() end ($last) precedes start ($first); ranges must be '
        'oriented start <= end.',
      );
    }
    final result = <DateTime>[];
    var cursor = first;
    while (!cursor.isAfter(last)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  /// Number of calendar days in the inclusive range, including both ends.
  int daysBetween(DateTime start, DateTime end) =>
      expandRange(start, end).length;

  /// Stable `YYYY-MM-DD` key for a calendar day (used for record ids and
  /// widget Keys/tests, and duplicates the service's date-key format).
  String dateKey(DateTime date) {
    final d = normalize(date);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}