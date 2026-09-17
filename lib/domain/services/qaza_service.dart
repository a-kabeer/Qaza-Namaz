import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

export '../entities/qaza_progress.dart';
export '../repositories/qaza_repository.dart' show QazaHistoryPage;

class QazaService {
  QazaService(this.repository);

  final QazaRepository repository;

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

  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) {
    return repository.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
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
    final date = QazaDate.normalize(originalDate);
    final now = DateTime.now();

    await repository.addRecord(
      QazaRecord(
        id: '${userId}_${prayerType.name}_${QazaDate.key(date)}',
        userId: userId,
        prayerType: prayerType,
        originalDate: date,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> recordQazaForDates({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
  }) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return;

    final now = DateTime.now();
    final records = <QazaRecord>[];

    for (final date in normalizedDates) {
      for (final prayerType in selectedPrayers) {
        records.add(
          QazaRecord(
            id: '${userId}_${prayerType.name}_${QazaDate.key(date)}',
            userId: userId,
            prayerType: prayerType,
            originalDate: date,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

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
