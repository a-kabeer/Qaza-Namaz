import '../../core/constants/prayer_types.dart';
import '../entities/qaza_activity.dart';

/// Persistence capability for the bounded offline Qaza activity projection.
///
/// Kept separate from the core QazaRepository contract so existing repository
/// fakes and non-activity consumers do not need unrelated activity methods.
abstract interface class QazaActivityRepository {
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  });
}
