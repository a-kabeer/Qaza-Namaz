import 'hijri_date.dart';

/// Shared calendar display vocabulary.
///
/// All human-readable calendar labels (month names, weekday initials,
/// formatted dates) live here so Gregorian and Hijri rendering is consistent
/// across every widget and never duplicated in a screen.
class CalendarLabels {
  CalendarLabels._();

  static const List<String> gregorianMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> gregorianMonthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Umm al-Qura Hijri month names (English) as used by the conversion table.
  static const List<String> hijriMonths = [
    'Muharram',
    'Safar',
    "Rabi' Al-Awwal",
    "Rabi' Al-Thani",
    'Jumada Al-Awwal',
    'Jumada Al-Thani',
    'Rajab',
    "Sha'aban",
    'Ramadan',
    'Shawwal',
    "Dhu Al-Qi'dah",
    'Dhu Al-Hijjah',
  ];

  static const List<String> weekdayInitials = [
    'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su',
  ];

  static String gregorianMonthName(int month) =>
      gregorianMonths[month - 1];

  static String gregorianMonthNameFull(int month) =>
      gregorianMonthsFull[month - 1];

  static String hijriMonthName(int month) => hijriMonths[month - 1];

  /// Formats a Gregorian date as `14 Sep 2026`.
  static String formatGregorianDate(DateTime date) =>
      '${date.day} ${gregorianMonths[date.month - 1]} ${date.year}';

  /// Formats a Hijri date as `3 Rabi' Al-Thani 1448 AH`.
  static String formatHijriDate(HijriDate date) =>
      '${date.day} ${hijriMonths[date.month - 1]} ${date.year} AH';

  /// Month-header label for a Gregorian month, e.g. `September 2026`.
  static String gregorianMonthHeader(DateTime firstOfMonth) =>
      '${gregorianMonthsFull[firstOfMonth.month - 1]} ${firstOfMonth.year}';

  /// Month-header label for a Hijri month, e.g. `Rabi' Al-Thani 1448 AH`.
  static String hijriMonthHeader(HijriDate firstOfMonth) =>
      '${hijriMonths[firstOfMonth.month - 1]} ${firstOfMonth.year} AH';

  /// Three-letter weekday names, Monday first so the index matches
  /// [DateTime.weekday] - 1.
  static const List<String> weekdayShortNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// Formats a Gregorian date as `05 Sep 2026` (zero-padded day), the display
  /// form used by the ledger, history and confirmations.
  static String formatGregorianDatePadded(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${gregorianMonths[date.month - 1]} ${date.year}';

  /// Formats a time of day as `3:45 PM`.
  static String formatClockTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }
}