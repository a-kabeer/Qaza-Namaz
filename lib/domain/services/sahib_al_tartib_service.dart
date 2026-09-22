import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

/// Result of applying the Sahib al-Tartib threshold to a user's outstanding
/// Qaza ledger.
///
/// The threshold counts only the five daily Fard prayers. Witr is excluded
/// from that count, but remains a Qaza prayer and therefore participates in
/// chronological prayer order when order is required.
class SahibAlTartibState {
  const SahibAlTartibState({
    required this.pendingFarzCount,
    required this.requiresOrder,
    required this.nextPending,
  });

  final int pendingFarzCount;
  final bool requiresOrder;
  final QazaRecord? nextPending;

  PrayerType? get nextPrayer => nextPending?.prayerType;
}

class SahibAlTartibService {
  const SahibAlTartibService(this.repository);

  static const int threshold = 6;

  static const List<PrayerType> farzPrayers = <PrayerType>[
    PrayerType.fajr,
    PrayerType.zuhr,
    PrayerType.asr,
    PrayerType.maghrib,
    PrayerType.isha,
  ];

  final QazaRepository repository;

  Future<SahibAlTartibState> evaluate({required String userId}) async {
    final summary = await repository.getProgressSummary(userId: userId);
    final pendingFarzCount = _pendingFarzCount(summary);

    if (pendingFarzCount >= threshold || pendingFarzCount == 0) {
      return SahibAlTartibState(
        pendingFarzCount: pendingFarzCount,
        requiresOrder: false,
        nextPending: null,
      );
    }

    QazaRecord? next;
    for (final prayer in PrayerType.values) {
      final candidate = await repository.getOldestPending(
        userId: userId,
        prayerType: prayer,
      );
      if (candidate == null) continue;
      if (next == null || _compare(candidate, next) < 0) {
        next = candidate;
      }
    }

    return SahibAlTartibState(
      pendingFarzCount: pendingFarzCount,
      requiresOrder: true,
      nextPending: next,
    );
  }

  int _pendingFarzCount(QazaProgressSummary summary) {
    var count = 0;
    for (final prayer in farzPrayers) {
      count += summary.byPrayer[prayer]?.progress.pending ?? 0;
    }
    return count;
  }

  /// Orders Qaza by original calendar date and, on the same date, by the
  /// prayer's actual daily sequence rather than enum/name ordering.
  static int _compare(QazaRecord a, QazaRecord b) {
    final date = a.originalDate.compareTo(b.originalDate);
    if (date != 0) return date;

    final prayer = _prayerOrder(a.prayerType).compareTo(
      _prayerOrder(b.prayerType),
    );
    if (prayer != 0) return prayer;

    return a.id.compareTo(b.id);
  }

  static int _prayerOrder(PrayerType prayer) => switch (prayer) {
        PrayerType.fajr => 0,
        PrayerType.zuhr => 1,
        PrayerType.asr => 2,
        PrayerType.maghrib => 3,
        PrayerType.isha => 4,
        PrayerType.witr => 5,
      };
}

/// Thrown when a completion request would violate the active Sahib al-Tartib
/// order. UI layers should localize the message using [requiredPrayer] rather
/// than displaying [toString] directly.
class QazaTartibViolationException implements Exception {
  const QazaTartibViolationException({
    required this.requiredPrayer,
    required this.pendingFarzCount,
  });

  final PrayerType requiredPrayer;
  final int pendingFarzCount;

  @override
  String toString() =>
      'Sahib al-Tartib requires ${requiredPrayer.name} to be completed first.';
}
