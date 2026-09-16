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

  Future<QazaAvailabilityAnalysis> analyzeAvailability({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final existing = await getRecords(userId: userId);
    return availability.analyze(
      userId: userId,
      dates: dates,
      prayerTypes: prayerTypes,
      existingRecords: existing,
      prayedKeys: prayedKeys,
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

  Future<void> recordQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime originalDate,
  }) async {
    await recordQazaForDates(
      userId: userId,
      dates: [originalDate],
      prayerTypes: [prayerType],
    );
  }

  /// Adds only combinations that are still eligible at save time.
  ///
  /// Existing pending and completed Qaza records are preserved. Re-checking
  /// the ledger immediately before insertion protects against stale UI state
  /// and repeated calculator/calendar submissions.
  Future<void> recordQazaForDates({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return;

    final existing = await getRecords(userId: userId);
    final analysis = availability.analyze(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      existingRecords: existing,
      prayedKeys: prayedKeys,
    );
    if (analysis.newCandidates.isEmpty) return;

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
  }

  Future<QazaRecord?> oldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final records = await getPendingForPrayer(
      userId: userId,
      prayerType: prayerType,
    );
    records.sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records.isEmpty ? null : records.first;
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
    final records = await getRecords(userId: userId);
    final validPendingIds = records
        .where(
          (record) =>
              selectedIds.contains(record.id) &&
              record.status == QazaStatus.pending,
        )
        .map((record) => record.id)
        .toList();

    if (validPendingIds.isEmpty) return 0;

    await completeRecords(
      userId: userId,
      recordIds: validPendingIds,
      completedAt: completedAt ?? DateTime.now(),
    );
    return validPendingIds.length;
  }

  Future<QazaProgress> overallProgress(String userId) async {
    final records = await getRecords(userId: userId);
    return _progress(records);
  }

  Future<PrayerProgress> prayerProgress(
    String userId,
    PrayerType prayerType,
  ) async {
    final records = await getRecords(
      userId: userId,
      prayerType: prayerType,
    );
    return PrayerProgress(
      prayerType: prayerType,
      progress: _progress(records),
    );
  }

  /// Completed records, newest completion first.
  ///
  /// Shared with the derived history provider so ordering is defined once.
  static List<QazaRecord> completedNewestFirst(
    Iterable<QazaRecord> records,
  ) {
    final completed = records
        .where((record) => record.status == QazaStatus.completed)
        .toList();
    completed.sort(
      (a, b) => (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return completed;
  }

  Future<List<QazaRecord>> history(String userId) async {
    final records = await getRecords(
      userId: userId,
      status: QazaStatus.completed,
    );
    return completedNewestFirst(records);
  }

  /// Pure progress math over records already in memory.
  ///
  /// Shared by the asynchronous ledger queries and by the derived state
  /// providers, so "what counts as progress" is defined exactly once.
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
