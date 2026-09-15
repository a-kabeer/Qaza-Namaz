class DateFormatters {
  DateFormatters._();

  static const List<String> gregorianMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> weekdayShortNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String gregorianMonthName(int month) => gregorianMonths[month - 1];

  static String formatGregorianDatePadded(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${gregorianMonthName(date.month)} ${date.year}';

  static String formatClockTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final suffix = value.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
}
