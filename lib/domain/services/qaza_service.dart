import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

class QazaService {
  QazaService(this.repository);

  final QazaRepository repository;

  Future<void> recordQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime originalDate,
  }) async {
    final now = DateTime.now();
    final id = '${userId}_${prayerType.name}_${_dateKey(originalDate)}';

    await repository.addRecord(
      QazaRecord(
        id: id,
        userId: userId,
        prayerType: prayerType,
        originalDate: DateTime(
          originalDate.year,
          originalDate.month,
          originalDate.day,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<QazaRecord?> oldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final records = await repository.getRecords(
      userId: userId,
      prayerType: prayerType,
      status: QazaStatus.pending,
    );

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

    await repository.completeRecord(
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
    final records = await repository.getRecords(userId: userId);
    final validPendingIds = records
        .where((r) => recordIds.contains(r.id) && r.status == QazaStatus.pending)
        .map((r) => r.id)
        .toList();

    if (validPendingIds.isEmpty) return 0;

    await repository.completeRecords(
      userId: userId,
      recordIds: validPendingIds,
      completedAt: completedAt ?? DateTime.now(),
    );

    return validPendingIds.length;
  }

  Future<QazaProgress> overallProgress(String userId) async {
    final records = await repository.getRecords(userId: userId);
    return _progress(records);
  }

  Future<PrayerProgress> prayerProgress(
    String userId,
    PrayerType prayerType,
  ) async {
    final records = await repository.getRecords(
      userId: userId,
      prayerType: prayerType,
    );
    return PrayerProgress(
      prayerType: prayerType,
      progress: _progress(records),
    );
  }

  Future<List<QazaRecord>> history(String userId) async {
    final records = await repository.getRecords(
      userId: userId,
      status: QazaStatus.completed,
    );
    records.sort(
      (a, b) => (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return records;
  }

  QazaProgress _progress(List<QazaRecord> records) {
    final completed =
        records.where((r) => r.status == QazaStatus.completed).length;
    return QazaProgress(
      pending: records.length - completed,
      completed: completed,
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
