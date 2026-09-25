import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

/// Global Sahib al-Tartib state for the active pending Qaza ledger.
///
/// The six-Fard threshold is calculated from all outstanding Fard Qaza.
/// Witr is excluded from that threshold. When fewer than six Fard prayers
/// remain, completion follows the deterministic oldest-first Fard order.
class SahibAlTartibState {
  const SahibAlTartibState({
    required this.pendingFarzCount,
    required this.requiresOrder,
    required this.nextPending,
  });

  /// Number of all outstanding pending Fard Qaza, excluding Witr.
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

  /// Evaluates Sahib al-Tartib from the user's complete pending ledger.
  ///
  /// The count is sourced from the repository's aggregate progress query so
  /// large ledgers are not materialized. The required next Fard is resolved
  /// with five bounded oldest-pending lookups, one per Fard prayer.
  Future<SahibAlTartibState> evaluate({
    required String userId,
    DateTime? today,
  }) async {
    final summary = await repository.getProgressSummary(userId: userId);
    final pendingFarzCount = _pendingFarzCount(summary);

    if (pendingFarzCount == 0 || pendingFarzCount >= threshold) {
      return SahibAlTartibState(
        pendingFarzCount: pendingFarzCount,
        requiresOrder: false,
        nextPending: null,
      );
    }

    final next = await _oldestPendingFarz(userId: userId);
    return SahibAlTartibState(
      pendingFarzCount: pendingFarzCount,
      requiresOrder: next != null,
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

  Future<QazaRecord?> _oldestPendingFarz({
    required String userId,
  }) async {
    final candidates = await Future.wait(
      farzPrayers.map(
        (prayer) => repository.getOldestPending(
          userId: userId,
          prayerType: prayer,
        ),
      ),
    );

    QazaRecord? next;
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (next == null || _compareFardOrder(candidate, next) < 0) {
        next = candidate;
      }
    }
    return next;
  }

  /// Orders by Qaza date first, then the actual daily Fard sequence, then id.
  static int _compareFardOrder(QazaRecord a, QazaRecord b) {
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

  /// Returns whether [recordIds] can be completed under the current order.
  ///
  /// When order is inactive, pending Fard and Witr are freely completable.
  /// When order is active, the required Fard is allowed and Witr remains
  /// independently completable according to the app's configured rule.
  Future<bool> canCompleteRecordIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final ids = recordIds.toSet();
    if (ids.isEmpty) return true;

    final state = await evaluate(userId: userId);
    if (!state.requiresOrder || state.nextPending == null) return true;

    final witrIds = await _findPendingWitrIds(
      userId: userId,
      requestedIds: ids,
    );

    return ids.every(
      (id) => id == state.nextPending!.id || witrIds.contains(id),
    );
  }

  /// Resolves the explicitly requested pending records and keeps only Witr.
  ///
  /// The repository contract uses bounded pages by default and can provide a
  /// more direct indexed implementation where available.
  Future<Set<String>> _findPendingWitrIds({
    required String userId,
    required Set<String> requestedIds,
  }) async {
    final records = await repository.getPendingRecordsByIds(
      userId: userId,
      recordIds: requestedIds,
    );
    return {
      for (final record in records)
        if (record.prayerType == PrayerType.witr) record.id,
    };
  }
}

/// Thrown when a completion request would violate the active Sahib al-Tartib
/// order. UI layers should localize the message using [requiredPrayer].
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
