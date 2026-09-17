import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import 'qaza_availability_service.dart';
import 'qaza_service.dart';

/// Large-range availability adapter.
///
/// Unlike the legacy full-ledger path, this reads only records inside the
/// requested date range and only for the selected prayers. The production
/// Drift/local path executes the range query in SQLite and does not require
/// materializing the user's complete ledger first.
extension QazaServiceBoundedAvailability on QazaService {
  Future<List<QazaRecord>> getExistingForAvailability({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const [];

    final sortedDates = normalizedDates.toList()..sort();
    final from = sortedDates.first;
    final to = sortedDates.last;
    final result = <QazaRecord>[];

    for (final prayer in selectedPrayers) {
      DateTime? beforeDate;
      String? beforeId;
      while (true) {
        final page = await repository.getHistoryPage(
          userId: userId,
          limit: 500,
          prayerType: prayer,
          status: null,
          from: from,
          to: to,
          beforeOriginalDate: beforeDate,
          beforeId: beforeId,
        );
        result.addAll(page.records);
        if (!page.hasMore) break;
        beforeDate = page.nextOriginalDate;
        beforeId = page.nextId;
      }
    }
    return result;
  }

  Future<QazaAvailabilityAnalysis> analyzeAvailabilityBounded({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final existing = await getExistingForAvailability(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
    );
    return availability.analyze(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      existingRecords: existing,
      prayedKeys: prayedKeys,
    );
  }

  Future<void> recordQazaForDatesBounded({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return;

    final analysis = await analyzeAvailabilityBounded(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      prayedKeys: prayedKeys,
    );
    if (analysis.newCandidates.isEmpty) return;

    final now = DateTime.now();
    await repository.addRecords([
      for (final candidate in analysis.newCandidates)
        QazaRecord(
          id: candidate.value,
          userId: userId,
          prayerType: candidate.prayerType,
          originalDate: candidate.date,
          status: QazaStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }
}
