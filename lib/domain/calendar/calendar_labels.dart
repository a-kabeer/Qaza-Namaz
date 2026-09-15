/// Shared Gregorian presentation helpers used by non-calendar UI.
///
/// This class contains no Hijri conversion, calendar arithmetic, or selection
/// state. Those responsibilities belong to the maintained `hijri` package and
/// the Riverpod calendar controller respectively.
class CalendarLabels {
  CalendarLabels._();

  static const List<String> gregorianMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> weekdayShortNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String gregorianMonthName(int month) => gregorianMonths[month - 1];

  static String formatGregorianDatePadded(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${gregorianMonths[date.month - 1]} ${date.year}';

  static String formatClockTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }
}