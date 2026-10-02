import '../../core/constants/prayer_types.dart';
import '../../core/time/local_date_service.dart';
import '../../core/calendar/fixed_hijri_arithmetic_service.dart';
import '../entities/user_profile.dart';
import 'profile_rules.dart';

class QazaPlan {
  const QazaPlan({
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.includeWitr,
    required this.totalPrayers,
    required this.prayerBreakdown,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final bool includeWitr;
  final int totalPrayers;
  final Map<PrayerType, int> prayerBreakdown;

  int get witrCount => includeWitr ? totalDays : 0;
  int get totalWithWitr => totalPrayers + witrCount;
}

/// Shared Qaza-plan domain logic.
///
/// The feature that originally calculated this lived under Calculator. The
/// calculation itself is useful domain behavior, so it is retained here and
/// now consumes the authoritative UserProfile rather than calculator state.
class QazaPlanService {
  const QazaPlanService();

  QazaPlan? planFor(UserProfile profile) {
    final start = ProfileRules.pubertyDate(profile);
    final startPrayingDate = ProfileRules.startPrayingDate(profile);
    final pubertyAge = profile.pubertyAge;
    final startPrayingAge = profile.startPrayingAge;
    if (start == null ||
        startPrayingDate == null ||
        pubertyAge == null ||
        startPrayingAge == null ||
        startPrayingAge < pubertyAge) {
      return null;
    }

    final totalDays = FixedHijriArithmeticService.durationForAges(
      pubertyAge: pubertyAge,
      startPrayingAge: startPrayingAge,
    );
    final end = LocalDateService.addCalendarDays(start, totalDays);
    if (end != startPrayingDate ||
        LocalDateService.compareCalendarDates(end, start) < 0) {
      return null;
    }

    final includeWitr = ProfileRules.effectiveWitr(profile);
    final prayerBreakdown = <PrayerType, int>{
      for (final prayer in PrayerType.values)
        if (prayer != PrayerType.witr) prayer: totalDays,
    };

    return QazaPlan(
      startDate: start,
      endDate: end,
      totalDays: totalDays,
      includeWitr: includeWitr,
      totalPrayers: totalDays * 5,
      prayerBreakdown: prayerBreakdown,
    );
  }

  /// Returns the canonical Gregorian ledger date for [offset] within [plan].
  ///
  /// Qaza plans use [startDate, endDate) semantics, so valid offsets are
  /// 0 through totalDays - 1.
  static DateTime planDateAt(QazaPlan plan, int offset) {
    if (offset < 0 || offset >= plan.totalDays) {
      throw RangeError.range(offset, 0, plan.totalDays - 1, 'offset');
    }
    return LocalDateService.addCalendarDays(plan.startDate, offset);
  }

  /// Enumerates exactly [QazaPlan.totalDays] consecutive Gregorian dates.
  static Iterable<DateTime> datesFor(QazaPlan plan) sync* {
    for (var offset = 0; offset < plan.totalDays; offset++) {
      yield planDateAt(plan, offset);
    }
  }
}
