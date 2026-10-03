import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';

enum CurrentDayQazaTimeEligibility {
  eligible,
  notYetDue,
  timeDataUnavailable,
}

/// Prayer-window cutoffs for the currently selected local day.
///
/// The timestamps are already converted to the prayer location's local
/// timezone by the prayer-time feature. This keeps the Qaza domain independent
/// of the timezone implementation.
class CurrentDayQazaPrayerTimeContext {
  const CurrentDayQazaPrayerTimeContext({
    required this.localNow,
    required this.localToday,
    required this.cutoffByPrayer,
    this.hasSchedule = true,
  });

  final DateTime localNow;
  final DateTime localToday;
  final Map<PrayerType, DateTime> cutoffByPrayer;
  final bool hasSchedule;

  DateTime? cutoffFor(PrayerType prayer) => cutoffByPrayer[prayer];
}

/// Reusable current-day prayer-time eligibility rule for Add Qaza.
///
/// Historical dates are unaffected. Current-day combinations are addable only
/// after the end of their current prayer window. Future-date restrictions stay
/// with the caller's existing date-selection rules.
class CurrentDayQazaEligibilityService {
  const CurrentDayQazaEligibilityService();

  CurrentDayQazaTimeEligibility evaluate({
    required DateTime date,
    required PrayerType prayerType,
    required CurrentDayQazaPrayerTimeContext context,
  }) {
    final normalizedDate = QazaDate.normalize(date);
    final localToday = QazaDate.normalize(context.localToday);

    if (normalizedDate != localToday) {
      return CurrentDayQazaTimeEligibility.eligible;
    }

    if (!context.hasSchedule) {
      return CurrentDayQazaTimeEligibility.timeDataUnavailable;
    }

    final cutoff = context.cutoffFor(prayerType);
    if (cutoff == null) {
      return CurrentDayQazaTimeEligibility.timeDataUnavailable;
    }

    return context.localNow.isBefore(cutoff)
        ? CurrentDayQazaTimeEligibility.notYetDue
        : CurrentDayQazaTimeEligibility.eligible;
  }
}
