import 'package:hijri/hijri_calendar.dart';

class DateFormatters {
  DateFormatters._();

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

  static String gregorianMonthName(int month) => gregorianMonths[month - 1];

  static String formatGregorianDatePadded(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${gregorianMonthName(date.month)} ${date.year}';

  /// The single Hijri display path. Gregorian remains the source of truth;
  /// this is derived information only, never a selection or storage format.
  static String hijriLabel(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} AH';
  }

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

  static String formatClockTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final suffix = value.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
}
