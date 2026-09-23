import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

/// Current-day Sahib al-Tartib state.
///
/// The ordered chain is limited to today's five Fard prayers:
/// Fajr -> Zuhr -> Asr -> Maghrib -> Isha.
/// Witr is intentionally outside this chain.
class SahibAlTartibState {
  const SahibAlTartibState({
    required this.pendingFarzCount,
    required this.requiresOrder,
    required this.nextPending,
  });

  /// Number of today's pending Fard Qaza records.
  final int pendingFarzCount;

  final bool requiresOrder;
  final QazaRecord? nextPending;

  PrayerType? get nextPrayer => nextPending?.prayerType;
}

class SahibAlTartibService {
  const SahibAlTartibService(this.repository);

  static const List<PrayerType> farzPrayers = <PrayerType>[
    PrayerType.fajr,
    PrayerType.zuhr,
    PrayerType.asr,
    PrayerType.maghrib,
    PrayerType.isha,
  ];

  final QazaRepository repository;

  Future<SahibAlTartibState> evaluate({
    required String userId,
    DateTime? today,
  }) async {
    final todayDate = QazaDate.normalize(today ?? DateTime.now());
    final page = await repository.getPage(
      userId: userId,
      limit: farzPrayers.length + 1,
      status: QazaStatus.pending,
      from: todayDate,
      to: todayDate,
    );

    final pendingByPrayer = <PrayerType, QazaRecord>{
      for (final record in page.records)
        if (farzPrayers.contains(record.prayerType))
          record.prayerType: record,
    };

    final pendingFarzCount = pendingByPrayer.length;
    if (pendingFarzCount == 0) {
      return const SahibAlTartibState(
        pendingFarzCount: 0,
        requiresOrder: false,
        nextPending: null,
      );
    }

    QazaRecord? next;
    for (final prayer in farzPrayers) {
      next = pendingByPrayer[prayer];
      if (next != null) break;
    }

    return SahibAlTartibState(
      pendingFarzCount: pendingFarzCount,
      requiresOrder: next != null,
      nextPending: next,
    );
  }

  /// Returns whether [recordIds] can be completed without violating the
  /// current-day Sahib al-Tartib sequence.
  ///
  /// Witr is independent from the five-prayer chain, so a pending Witr from
  /// today remains completable while a Fard prayer is waiting.
  Future<bool> canCompleteRecordIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final ids = recordIds.toSet();
    if (ids.isEmpty) return true;

    final state = await evaluate(userId: userId);
    if (!state.requiresOrder || state.nextPending == null) return true;

    final today = QazaDate.normalize(DateTime.now());
    final page = await repository.getPage(
      userId: userId,
      limit: farzPrayers.length + 1,
      status: QazaStatus.pending,
      from: today,
      to: today,
    );

    final allowedIds = <String>{state.nextPending!.id};
    allowedIds.addAll(
      page.records
          .where((record) => record.prayerType == PrayerType.witr)
          .map((record) => record.id),
    );

    return ids.every(allowedIds.contains);
  }
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
