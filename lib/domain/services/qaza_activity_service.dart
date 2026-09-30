import '../../core/constants/prayer_types.dart';
import '../entities/qaza_activity.dart';
import '../repositories/qaza_activity_repository.dart';

/// Builds activity periods from a bounded completion projection.
///
/// This service intentionally contains no Qaza business rules. Profile-aware
/// prayer eligibility is supplied by the existing provider layer.
class QazaActivityService {
  QazaActivityService(
    this.repository, {
    required Iterable<PrayerType> enabledPrayerTypes,
  }) : enabledPrayerTypes = List<PrayerType>.unmodifiable(
          enabledPrayerTypes,
        );

  final QazaActivityRepository repository;
  final List<PrayerType> enabledPrayerTypes;

  Future<QazaActivityPeriod> buildPeriod({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    required DateTime today,
    required int dailyTarget,
  }) async {
    final normalizedFrom = _dateOnly(from);
    final normalizedTo = _dateOnly(toExclusive);
    final normalizedToday = _dateOnly(today);

    if (!normalizedFrom.isBefore(normalizedTo)) {
      throw ArgumentError('from must be before toExclusive');
    }

    final rows = enabledPrayerTypes.isEmpty
        ? const <QazaActivityRow>[]
        : await repository.getCompletedActivityRows(
            userId: userId,
            from: normalizedFrom,
            toExclusive: normalizedTo,
            prayerTypes: enabledPrayerTypes,
          );

    return buildPeriodFromRows(
      rows: rows,
      from: normalizedFrom,
      toExclusive: normalizedTo,
      today: normalizedToday,
      dailyTarget: dailyTarget,
      enabledPrayerTypes: enabledPrayerTypes,
    );
  }

  Future<QazaActivityPeriod> buildRolling({
    required String userId,
    required DateTime today,
    required int days,
    required int dailyTarget,
  }) {
    if (days < 1) throw ArgumentError.value(days, 'days');

    final normalizedToday = _dateOnly(today);
    final from = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day - (days - 1),
    );
    final toExclusive = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day + 1,
    );

    return buildPeriod(
      userId: userId,
      from: from,
      toExclusive: toExclusive,
      today: normalizedToday,
      dailyTarget: dailyTarget,
    );
  }

  /// Builds the current local Sunday-through-Saturday calendar week.
  Future<QazaActivityPeriod> buildCurrentCalendarWeek({
    required String userId,
    required DateTime today,
    required int dailyTarget,
  }) {
    final normalizedToday = _dateOnly(today);
    final from = calendarWeekStartForDate(normalizedToday);
    final toExclusive = calendarWeekEndExclusiveForDate(normalizedToday);

    return buildPeriod(
      userId: userId,
      from: from,
      toExclusive: toExclusive,
      today: normalizedToday,
      dailyTarget: dailyTarget,
    );
  }

  /// Returns the Sunday at the start of the local calendar week containing [date].
  static DateTime calendarWeekStartForDate(DateTime date) {
    final normalized = _dateOnly(date);
    final daysSinceSunday = normalized.weekday % 7;
    return DateTime(
      normalized.year,
      normalized.month,
      normalized.day - daysSinceSunday,
    );
  }

  /// Returns the exclusive boundary immediately after the Saturday of [date]'s week.
  static DateTime calendarWeekEndExclusiveForDate(DateTime date) =>
      DateTime(
        calendarWeekStartForDate(date).year,
        calendarWeekStartForDate(date).month,
        calendarWeekStartForDate(date).day + 7,
      );

  /// The weekly target always represents all seven calendar days, including future days.
  static int weeklyTargetFromDailyTarget(int dailyTarget) {
    if (dailyTarget <= 0) return 0;
    return dailyTarget * 7;
  }

  Future<QazaActivityPeriod> buildMonth({
    required String userId,
    required DateTime month,
    required DateTime today,
    required int dailyTarget,
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
    );
  }

  /// Pure aggregation entry point used by unit tests and by [buildPeriod].
  static QazaActivityPeriod buildPeriodFromRows({
    required Iterable<QazaActivityRow> rows,
    required DateTime from,
    required DateTime toExclusive,
    required DateTime today,
    required int dailyTarget,
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

    for (final row in rows) {
      if (!enabled.contains(row.prayerType)) continue;

      // completedAt is an instant. Activity is attributed to the device's
      // local calendar day, matching Home's existing local-day convention.
      final local = row.completedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);

      if (date.isBefore(normalizedFrom) || !date.isBefore(normalizedTo)) {
        continue;
      }

      final perPrayer = counts.putIfAbsent(
        date,
        () => <PrayerType, int>{},
      );
      perPrayer[row.prayerType] =
          (perPrayer[row.prayerType] ?? 0) + 1;
    }

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
          target: dailyTarget < 0 ? 0 : dailyTarget,
          isFuture: date.isAfter(normalizedToday),
        ),
      );
    }

    return QazaActivityPeriod(
      from: normalizedFrom,
      toExclusive: normalizedTo,
      today: normalizedToday,
      days: List<QazaDailyActivity>.unmodifiable(days),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _nextDate(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);
}
