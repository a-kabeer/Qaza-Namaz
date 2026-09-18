import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/database/app_database.dart';

class DriftQazaRepository implements QazaRepository {
  DriftQazaRepository(this.database);
  final AppDatabase database;

  @override
  Future<List<QazaRecord>> getRecords(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    final rows = <QazaRecord>[];
    DateTime? afterDate;
    String? afterId;
    while (true) {
      final page = await getPage(
          userId: userId,
          limit: 500,
          prayerType: prayerType,
          status: status,
          afterOriginalDate: afterDate,
          afterId: afterId);
      rows.addAll(page.records);
      if (!page.hasMore) return rows;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }
  }

  @override
  Future<QazaPage> getPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status,
      DateTime? from,
      DateTime? to,
      DateTime? afterOriginalDate,
      String? afterId}) async {
    final page = await database.qazaRecordsDao.getKeysetPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType?.name,
        status: status?.name,
        from: from,
        to: to,
        afterOriginalDate: afterOriginalDate,
        afterId: afterId);
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending(
          {required String userId, required PrayerType prayerType}) =>
      database.qazaRecordsDao
          .getOldestPending(userId: userId, prayerType: prayerType.name)
          .then((row) => row);

  @override
  Future<QazaHistoryPage> getHistoryPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status = QazaStatus.completed,
      DateTime? from,
      DateTime? to,
      DateTime? beforeOriginalDate,
      String? beforeId}) async {
    final page = await database.qazaRecordsDao.getHistoryPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType?.name,
        status: status?.name,
        from: from,
        to: to,
        beforeOriginalDate: beforeOriginalDate,
        beforeId: beforeId);
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    final counts =
        await database.qazaRecordsDao.getProgressCounts(userId: userId);
    final pending = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0
    };
    final completed = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0
    };
    for (final entry in counts.entries) {
      pending[entry.key] = entry.value[QazaStatus.pending] ?? 0;
      completed[entry.key] = entry.value[QazaStatus.completed] ?? 0;
    }
    return QazaProgressSummary(
        overall: QazaProgress(
            pending: pending.values.fold(0, (a, b) => a + b),
            completed: completed.values.fold(0, (a, b) => a + b)),
        byPrayer: {
          for (final prayer in PrayerType.values)
            prayer: PrayerProgress(
                prayerType: prayer,
                progress: QazaProgress(
                    pending: pending[prayer]!, completed: completed[prayer]!))
        });
  }

  @override
  Future<void> addRecord(QazaRecord record) =>
      database.qazaRecordsDao.insertRecord(_toCompanion(record));

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userIds = records.map((record) => record.userId).toSet();
    if (userIds.length != 1) {
      throw StateError('A Qaza batch mutation must belong to one user.');
    }
    await database.qazaRecordsDao
        .insertRecords(records.map(_toCompanion).toList(growable: false));
  }

  @override
  Future<void> completeRecord(
          {required String userId,
          required String recordId,
          required DateTime completedAt}) =>
      completeRecords(
          userId: userId, recordIds: [recordId], completedAt: completedAt);

  @override
  Future<void> completeRecords(
      {required String userId,
      required List<String> recordIds,
      required DateTime completedAt}) async {
    if (recordIds.isEmpty) return;
    await database.transaction(() async {
      for (final id in recordIds.toSet()) {
        final existing =
            await database.qazaRecordsDao.findById(userId: userId, id: id);
        if (existing == null || existing.status == QazaStatus.completed)
          continue;
        await database.qazaRecordsDao.updateRecord(existing.copyWith(
            status: QazaStatus.completed,
            completedAt: completedAt,
            updatedAt: completedAt));
      }
    });
  }

  QazaRecordsCompanion _toCompanion(QazaRecord r) =>
      QazaRecordsCompanion.insert(
          id: r.id,
          userId: r.userId,
          prayerType: r.prayerType.name,
          originalDate: r.originalDate,
          status: r.status.name,
          completedAt: r.completedAt == null
              ? const Value.absent()
              : Value(r.completedAt),
          createdAt: r.createdAt,
          updatedAt: r.updatedAt);
}
