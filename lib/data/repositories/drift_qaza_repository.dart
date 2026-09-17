import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/database/app_database.dart';
import '../local/database/tables/qaza_records.dart';

/// QazaRepository implementation backed by Drift/SQLite.
class DriftQazaRepository implements QazaRepository {
  DriftQazaRepository(this.database);

  final AppDatabase database;

  static const int _pageSize = 500;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    final rows = <QazaRecord>[];
    var offset = 0;
    while (true) {
      final page = await database.qazaRecordsDao.getPage(
        userId: userId,
        limit: _pageSize,
        offset: offset,
        prayerType: prayerType?.name,
        status: status?.name,
      );
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += page.length;
    }
    return rows;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    final page = await database.qazaRecordsDao.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType?.name,
      status: status?.name,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    final counts = await database.qazaRecordsDao.getProgressCounts(userId: userId);
    final pending = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0,
    };
    final completed = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0,
    };

    for (final entry in counts.entries) {
      pending[entry.key] = entry.value[QazaStatus.pending] ?? 0;
      completed[entry.key] = entry.value[QazaStatus.completed] ?? 0;
    }

    return QazaProgressSummary(
      overall: QazaProgress(
        pending: pending.values.fold(0, (total, count) => total + count),
        completed: completed.values.fold(0, (total, count) => total + count),
      ),
      byPrayer: {
        for (final prayer in PrayerType.values)
          prayer: PrayerProgress(
            prayerType: prayer,
            progress: QazaProgress(
              pending: pending[prayer]!,
              completed: completed[prayer]!,
            ),
          ),
      },
    );
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    await database.qazaRecordsDao.insertRecord(_toCompanion(record));
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    await database.qazaRecordsDao.insertRecords(
      records.map(_toCompanion).toList(growable: false),
    );
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    await completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty) return;

    await database.transaction(() async {
      for (final id in recordIds.toSet()) {
        final existing = await database.qazaRecordsDao.findById(
          userId: userId,
          id: id,
        );
        if (existing == null || existing.status == QazaStatus.completed) continue;

        final updated = existing.copyWith(
          status: QazaStatus.completed,
          completedAt: completedAt,
          updatedAt: completedAt,
        );
        await database.qazaRecordsDao.updateRecord(updated);
      }
    });
  }

  QazaRecordsCompanion _toCompanion(QazaRecord record) {
    return QazaRecordsCompanion.insert(
      id: record.id,
      userId: record.userId,
      prayerType: record.prayerType.name,
      originalDate: record.originalDate,
      status: record.status.name,
      completedAt: record.completedAt == null
          ? const Value.absent()
          : Value(record.completedAt),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }
}
