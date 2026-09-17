import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import 'qaza_availability_service.dart';

export '../entities/qaza_progress.dart';

class QazaService {
  QazaService(this.repository, {QazaAvailabilityService? availability})
      : availability = availability ?? const QazaAvailabilityService();

  final QazaRepository repository;
  final QazaAvailabilityService availability;

  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) {
    return repository.getRecords(
      userId: userId,
      prayerType: prayerType,
      status: status,
    );
  }

  Future<List<QazaRecord>> getPendingForUser({required String userId}) {
    return getRecords(userId: userId, status: QazaStatus.pending);
  }

  Future<List<QazaRecord>> getPendingForPrayer({
    required String userId,
    required PrayerType prayerType,
  }) {
    return getRecords(
      userId: userId,
      prayerType: prayerType,
      status: QazaStatus.pending,
    );
  }

  /// Analyzes only the requested date/prayer window.
  ///
  /// This is intentionally bounded: callers such as the calculator must not
  /// materialize the user's complete Qaza ledger just to detect overlap.
  Future<QazaAvailabilityAnalysis> analyzeAvailability({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    if (normalizedDates.isEmpty || prayerTypes.isEmpty) {
      return availability.analyze(
        userId: userId,
        dates: normalizedDates,
        prayerTypes: prayerTypes,
        existingRecords: const <QazaRecord>[],
        prayedKeys: prayedKeys,
      );
    }

    final existing = await repository.getRecordsForDates(
      userId: userId,
      dates: normalizedDates,
    );
    return availability.analyze(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: prayerTypes,
      existingRecords: existing,
      prayedKeys: prayedKeys,
    );
  }

  /// Loads availability for one visible calendar month only.
  ///
  /// The repository query is bounded to the month's dates, so navigating the
  /// calendar never requires loading the user's complete ledger.
  Future<Set<DateTime>> unavailableDatesForMonth({
    required String userId,
    required DateTime month,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
    Iterable<PrayerType> prayerTypes = PrayerType.values,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final dates = <DateTime>[];
    for (var date = start;
        !date.isAfter(end);
        date = DateTime(date.year, date.month, date.day + 1)) {
      dates.add(date);
    }

    final existing = await repository.getRecordsForDates(
      userId: userId,
      dates: dates,
    );
    return availability.unavailableDatesForMonth(
      userId: userId,
      month: month,
      existingRecords: existing,
      prayedKeys: prayedKeys,
      prayerTypes: prayerTypes,
    );
  }

  Future<void> addRecords(List<QazaRecord> records) {
    return repository.addRecords(records);
  }

  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) {
    return repository.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
  }

  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    return repository.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }

  Future<int> recordQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime originalDate,
  }) {
    return recordQazaForDates(
      userId: userId,
      dates: [originalDate],
      prayerTypes: [prayerType],
    );
  }

  /// Adds only combinations that are still eligible at save time.
  ///
  /// The returned value is the number of candidates that passed the final
  /// availability check and were submitted to the repository. Existing
  /// pending/completed records are preserved and duplicate IDs remain safe.
  Future<int> recordQazaForDates({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return 0;

    final analysis = await analyzeAvailability(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      prayedKeys: prayedKeys,
    );
    if (analysis.newCandidates.isEmpty) return 0;

    final now = DateTime.now();
    final records = [
      for (final candidate in analysis.newCandidates)
        QazaRecord(
          id: candidate.value,
          userId: userId,
          prayerType: candidate.prayerType,
          originalDate: candidate.date,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    await repository.addRecords(records);
    return records.length;
  }

  Future<QazaRecord?> oldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final page = await repository.getHistoryPage(
      userId: userId,
      prayerType: prayerType,
      status: QazaStatus.pending,
      limit: 1,
      ascending: true,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<bool> completeOldestPending({
    required String userId,
    required PrayerType prayerType,
    DateTime? completedAt,
  }) async {
    final record = await oldestPending(
      userId: userId,
      prayerType: prayerType,
    );
    if (record == null) return false;

    await completeRecord(
      userId: userId,
      recordId: record.id,
      completedAt: completedAt ?? DateTime.now(),
    );
    return true;
  }

  Future<int> completeSelected({
    required String userId,
    required List<String> recordIds,
    DateTime? completedAt,
  }) async {
    if (recordIds.isEmpty) return 0;

    final selectedIds = recordIds.toSet();
    final records = await repository.getRecordsByIds(
      userId: userId,
      recordIds: selectedIds,
    );
    final validPendingIds = records
        .where(
          (record) =>
              selectedIds.contains(record.id) &&
              record.status == QazaStatus.pending,
        )
        .map((record) => record.id)
        .toList(growable: false);

    if (validPendingIds.isEmpty) return 0;

    await completeRecords(
      userId: userId,
      recordIds: validPendingIds,
      completedAt: completedAt ?? DateTime.now(),
    );
    return validPendingIds.length;
  }

  Future<QazaProgress> overallProgress(String userId) async {
    final summary = await repository.getSummary(userId);
    return QazaProgress(pending: summary.pending, completed: summary.completed);
  }

  Future<PrayerProgress> prayerProgress(
    String userId,
    PrayerType prayerType,
  ) async {
    final summary = await repository.getSummary(userId);
    return PrayerProgress(
      prayerType: prayerType,
      progress: summary.byPrayer[prayerType] ??
          const QazaProgress(pending: 0, completed: 0),
    );
  }

  static List<QazaRecord> completedNewestFirst(
    Iterable<QazaRecord> records,
  ) {
    final completed = records
        .where((record) => record.status == QazaStatus.completed)
        .toList();
    completed.sort(
      (a, b) =>
          (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );
    return completed;
  }

  Future<List<QazaRecord>> history(String userId) async {
    return completedNewestFirst(
      await getRecords(userId: userId, status: QazaStatus.completed),
    );
  }

  static QazaProgress progressOf(Iterable<QazaRecord> records) {
    var completed = 0;
    var total = 0;
    for (final record in records) {
      total++;
      if (record.status == QazaStatus.completed) completed++;
    }
    final pending = total - completed;
    return QazaProgress(
      pending: pending < 0 ? 0 : pending,
      completed: completed,
    );
  }

  QazaProgress _progress(List<QazaRecord> records) => progressOf(records);
}
