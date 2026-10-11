import 'package:intl/intl.dart' as intl;

class DateFormatters {
  DateFormatters._();

  // Retained for callers that need the English month labels as data. User-facing
  // date strings below are formatted from the active Intl locale instead.
  static const List<String> gregorianMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> weekdayShortNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> gregorianMonthsFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String gregorianMonthName(int month) =>
      intl.DateFormat('MMM').format(DateTime(2000, month, 1));

  static String gregorianMonthFullName(int month) =>
      intl.DateFormat('MMMM').format(DateTime(2000, month, 1));

  /// The complete Gregorian date — day, localized month, and year.
  ///
  /// Gregorian remains the canonical date even when Urdu is selected.
  static String formatGregorianFull(DateTime date) =>
      intl.DateFormat('d MMMM yyyy').format(date);

  static String formatGregorianDatePadded(DateTime date) =>
      intl.DateFormat('dd MMM yyyy').format(date);

  /// Compact Gregorian date with a localized short weekday.
  static String formatGregorianWeekdayShortFull(DateTime date) =>
      intl.DateFormat('EEE, MMM d, yyyy').format(date);

  static String formatWeekdayShort(DateTime date) =>
      intl.DateFormat('EEE').format(date);

  /// Groups a count with thousands separators, e.g. `4380` becomes `4,380`.
  static String formatCount(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  /// Formats a countdown as zero-padded HH:MM:SS.
  static String formatDurationHhMmSs(Duration duration) {
    final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String formatClockTime(DateTime value) =>
      intl.DateFormat('hh:mm a').format(value);
}
