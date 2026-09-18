import '../../core/constants/prayer_types.dart';

class QazaCalculation {
  const QazaCalculation({
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.calendarYears,
    required this.remainingDays,
    required this.dailyPrayerCount,
    required this.totalPrayers,
    required this.prayerBreakdown,
    required this.includeWitr,
    required this.witrCount,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final int calendarYears;
  final int remainingDays;
  final int dailyPrayerCount;
  final int totalPrayers;
  final Map<PrayerType, int> prayerBreakdown;
  final bool includeWitr;
  final int witrCount;

  int get totalWithWitr => totalPrayers + witrCount;
}

/// Calculates the Qaza period between two calendar dates.
///
/// ## Date-boundary contract
///
/// The period is **start inclusive, end exclusive**: `startDate` (the Baligh
/// date) counts as a missed day, `endDate` (the day regular prayer began) does
/// not. So `totalDays == endDate.difference(startDate).inDays`, equal dates
/// produce zero days, and one calendar day apart produces exactly one day.
///
/// This single rule is used everywhere — `totalPrayers`, `prayerBreakdown`,
/// `witrCount` and the tracker expansion in `trackerDates` all derive from
/// `totalDays`, so the generated records always match the displayed count.
///
/// Both arguments are reduced to their calendar date, so a time-of-day
/// component never shifts the result. `endDate` before `startDate` throws
/// [ArgumentError] rather than producing a negative period.
QazaCalculation calculateQaza({
  required DateTime startDate,
  required DateTime endDate,
  bool includeWitr = false,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  if (end.isBefore(start)) {
    throw ArgumentError.value(
        endDate, 'endDate', 'must be on or after startDate');
  }
  final totalDays = end.difference(start).inDays;
  final calendarYears = _calendarYearsBetween(start, end);
  final anniversary =
      DateTime(start.year + calendarYears, start.month, start.day);
  final remainingDays = end.difference(anniversary).inDays;
  const dailyPrayerCount = 5;
  final totalPrayers = totalDays * dailyPrayerCount;
  final prayerBreakdown = <PrayerType, int>{
    for (final prayer in PrayerType.values.where((p) => p != PrayerType.witr))
      prayer: totalDays,
  };
  return QazaCalculation(
    startDate: start,
    endDate: end,
    totalDays: totalDays,
    calendarYears: calendarYears,
    remainingDays: remainingDays,
    dailyPrayerCount: dailyPrayerCount,
    totalPrayers: totalPrayers,
    prayerBreakdown: prayerBreakdown,
    includeWitr: includeWitr,
    witrCount: includeWitr ? totalDays : 0,
  );
}

int _calendarYearsBetween(DateTime start, DateTime end) {
  var years = end.year - start.year;
  final anniversary = DateTime(end.year, start.month, start.day);
  if (anniversary.isAfter(end)) years--;
  return years;
}
