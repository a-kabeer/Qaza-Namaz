import '../../core/constants/prayer_types.dart';
import '../entities/qaza_activity.dart';
import '../repositories/qaza_activity_repository.dart';

/// Builds calendar-based Qaza activity from a bounded completion projection.
///
/// Activity is historical fact and is always based on completedAt. Targets are
/// separate planning data and are only exposed when the caller knows they are
/// meaningful for the selected period.
class QazaActivityService {
  QazaActivityService(
    this.repository, {
    required Iterable<PrayerType> enabledPrayerTypes,
  }) : enabledPrayerTypes = List<PrayerType>.unmodifiable(
          enabledPrayerTypes,
        );

  final QazaActivityRepository repository;

  /// The production provider supplies all prayer types so profile changes
  /// cannot erase historical activity such as completed Witr records.
  final List<PrayerType> enabledPrayerTypes;

  Future<QazaActivityPeriod> buildPeriod({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    required DateTime today,
    required int dailyTarget,
    bool targetAvailable = true,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    final normalizedFrom = _dateOnly(from);
    final normalizedTo = _dateOnly(toExclusive);
    final normalizedToday = _dateOnly(today);

    if (!normalizedFrom.isBefore(normalizedTo)) {
      throw ArgumentError('from must be before toExclusive');
    }

    final activityPrayerTypes =
        List<PrayerType>.unmodifiable(prayerTypes ?? enabledPrayerTypes);
    final rows = activityPrayerTypes.isEmpty
        ? const <QazaActivityRow>[]
        : await repository.getCompletedActivityRows(
            userId: userId,
            from: normalizedFrom,
            toExclusive: normalizedTo,
            prayerTypes: activityPrayerTypes,
          );

    return buildPeriodFromRows(
      rows: rows,
      from: normalizedFrom,
      toExclusive: normalizedTo,
      today: normalizedToday,
      dailyTarget: dailyTarget,
      targetAvailable: targetAvailable,
      enabledPrayerTypes: activityPrayerTypes,
    );
  }

  Future<QazaActivityPeriod> buildWeek({
    required String userId,
    required DateTime selectedDate,
    required DateTime today,
    required int dailyTarget,
    bool targetAvailable = false,
  }) {
    final normalizedSelectedDate = _dateOnly(selectedDate);
    final from = calendarWeekStartForDate(normalizedSelectedDate);
    return buildPeriod(
      userId: userId,
      from: from,
      toExclusive: DateTime(from.year, from.month, from.day + 7),
      today: today,
      dailyTarget: dailyTarget,
      targetAvailable: targetAvailable,
      prayerTypes: prayerTypes,
    );
  }

  Future<QazaActivityPeriod> buildCurrentCalendarWeek({
    required String userId,
    required DateTime today,
    required int dailyTarget,
  }) {
    final normalizedToday = _dateOnly(today);
    return buildWeek(
      userId: userId,
      selectedDate: normalizedToday,
      today: normalizedToday,
      dailyTarget: dailyTarget,
      targetAvailable: true,
    );
  }

  static DateTime calendarWeekStartForDate(DateTime date) {
    final normalized = _dateOnly(date);
    final daysSinceSunday = normalized.weekday % 7;
    return DateTime(
      normalized.year,
      normalized.month,
      normalized.day - daysSinceSunday,
    );
  }

  static DateTime calendarWeekEndExclusiveForDate(DateTime date) {
    final start = calendarWeekStartForDate(date);
    return DateTime(start.year, start.month, start.day + 7);
  }

  static int weeklyTargetFromDailyTarget(int dailyTarget) {
    if (dailyTarget <= 0) return 0;
    return dailyTarget * 7;
  }

  Future<QazaActivityPeriod> buildMonth({
    required String userId,
    required DateTime month,
    required DateTime today,
    required int dailyTarget,
    bool targetAvailable = false,
    Iterable<PrayerType>? prayerTypes,
  }) {
    final normalizedMonth = _dateOnly(month);
    final from = DateTime(normalizedMonth.year, normalizedMonth.month);
    final toExclusive =
        DateTime(normalizedMonth.year, normalizedMonth.month + 1);
    return buildPeriod(
      userId: userId,
      from: from,
      toExclusive: toExclusive,
      today: today,
      dailyTarget: dailyTarget,
      targetAvailable: targetAvailable,
      prayerTypes: prayerTypes,
    );
  }

  Future<QazaActivityPeriod> buildYear({
    required String userId,
    required DateTime year,
    required DateTime today,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    final normalizedYear = DateTime(year.year);
    final from = DateTime(normalizedYear.year, 1, 1);
    final toExclusive = DateTime(normalizedYear.year + 1, 1, 1);

    final activityPrayerTypes =
        List<PrayerType>.unmodifiable(prayerTypes ?? enabledPrayerTypes);
    final rows = activityPrayerTypes.isEmpty
        ? const <QazaActivityRow>[]
        : await repository.getCompletedActivityRows(
            userId: userId,
            from: from,
            toExclusive: toExclusive,
            prayerTypes: activityPrayerTypes,
          );

    return buildYearFromRows(
      rows: rows,
      from: from,
      toExclusive: toExclusive,
      today: today,
      enabledPrayerTypes: activityPrayerTypes,
    );
  }

  static QazaActivityPeriod buildPeriodFromRows({
    required Iterable<QazaActivityRow> rows,
    required DateTime from,
    required DateTime toExclusive,
    required DateTime today,
    required int dailyTarget,
    required Iterable<PrayerType> enabledPrayerTypes,
    bool targetAvailable = true,
  }) {
    final normalizedFrom = _dateOnly(from);
    final normalizedTo = _dateOnly(toExclusive);
    final normalizedToday = _dateOnly(today);

    if (!normalizedFrom.isBefore(normalizedTo)) {
      throw ArgumentError('from must be before toExclusive');
    }

    final enabled = enabledPrayerTypes.toSet();
    final counts = <DateTime, Map<PrayerType, int>>{};

    for (final row in rows) {
      if (!enabled.contains(row.prayerType)) continue;

      final local = row.completedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);

      if (date.isBefore(normalizedFrom) ||
          !date.isBefore(normalizedTo) ||
          date.isAfter(normalizedToday)) {
        continue;
      }

      final perPrayer = counts.putIfAbsent(
        date,
        () => <PrayerType, int>{},
      );
      perPrayer[row.prayerType] =
          (perPrayer[row.prayerType] ?? 0) + 1;
    }

    final effectiveTarget =
        targetAvailable && dailyTarget > 0 ? dailyTarget : 0;

    final days = <QazaDailyActivity>[];
    for (
      var date = normalizedFrom;
      date.isBefore(normalizedTo);
      date = _nextDate(date)
    ) {
      final perPrayer = <PrayerType, int>{
        for (final prayer in enabled) prayer: 0,
      };
      perPrayer.addAll(counts[date] ?? const <PrayerType, int>{});
      final completed = perPrayer.values.fold(0, (sum, count) => sum + count);

      days.add(
        QazaDailyActivity(
          date: date,
          completed: completed,
          byPrayer: Map<PrayerType, int>.unmodifiable(perPrayer),
          target: effectiveTarget,
          isFuture: date.isAfter(normalizedToday),
        ),
      );
    }

    return QazaActivityPeriod(
      from: normalizedFrom,
      toExclusive: normalizedTo,
      today: normalizedToday,
      days: List<QazaDailyActivity>.unmodifiable(days),
      targetAvailable: targetAvailable,
      dailyTarget: effectiveTarget,
    );
  }

  static QazaActivityPeriod buildYearFromRows({
    required Iterable<QazaActivityRow> rows,
    required DateTime from,
    required DateTime toExclusive,
    required DateTime today,
    required Iterable<PrayerType> enabledPrayerTypes,
  }) {
    final normalizedFrom = _dateOnly(from);
    final normalizedTo = _dateOnly(toExclusive);
    final normalizedToday = _dateOnly(today);

    if (!normalizedFrom.isBefore(normalizedTo)) {
      throw ArgumentError('from must be before toExclusive');
    }

    final enabled = enabledPrayerTypes.toSet();
    final counts = <DateTime, Map<PrayerType, int>>{};
    final activeDays = <DateTime>{};
    final activeMonths = <DateTime>{};

    for (final row in rows) {
      if (!enabled.contains(row.prayerType)) continue;

      final local = row.completedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);

      if (date.isBefore(normalizedFrom) ||
          !date.isBefore(normalizedTo) ||
          date.isAfter(normalizedToday)) {
        continue;
      }

      final month = DateTime(date.year, date.month);
      final perPrayer = counts.putIfAbsent(
        month,
        () => <PrayerType, int>{},
      );
      perPrayer[row.prayerType] =
          (perPrayer[row.prayerType] ?? 0) + 1;
      activeDays.add(date);
      activeMonths.add(month);
    }

    final buckets = <QazaDailyActivity>[];
    for (var monthIndex = 1; monthIndex <= 12; monthIndex++) {
      final month = DateTime(normalizedFrom.year, monthIndex);
      final perPrayer = <PrayerType, int>{
        for (final prayer in enabled) prayer: 0,
      };
      perPrayer.addAll(counts[month] ?? const <PrayerType, int>{});

      buckets.add(
        QazaDailyActivity(
          date: month,
          completed: perPrayer.values.fold(0, (sum, count) => sum + count),
          byPrayer: Map<PrayerType, int>.unmodifiable(perPrayer),
          target: 0,
          isFuture: month.isAfter(
            DateTime(normalizedToday.year, normalizedToday.month),
          ),
        ),
      );
    }

    return QazaActivityPeriod(
      from: normalizedFrom,
      toExclusive: normalizedTo,
      today: normalizedToday,
      days: List<QazaDailyActivity>.unmodifiable(buckets),
      targetAvailable: false,
      dailyTarget: 0,
      activeDays: activeDays.length,
      activeMonths: activeMonths.length,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _nextDate(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);
}
