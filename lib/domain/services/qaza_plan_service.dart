import '../../core/constants/prayer_types.dart';
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
    final end = ProfileRules.startPrayingDate(profile);
    if (start == null || end == null || end.isBefore(start)) return null;

    final totalDays = end.difference(start).inDays;
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
}
