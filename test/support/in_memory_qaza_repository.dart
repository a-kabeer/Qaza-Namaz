import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_remote_data_source.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';

class InMemoryQazaRepository
    implements QazaRepository, QazaSyncRemoteDataSource {
  final Map<String, QazaRecord> _records = {};
  int historyPageCalls = 0;
  int progressSummaryCalls = 0;
  final Map<String, List<QazaRemoteChange>> _changesByUser = {};
  final Map<String, int> _generations = {};
  int _changeSequence = 0;

  @override
  Future<List<QazaRecord>> getRecords(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    final page = await _collectPages(
        userId: userId, prayerType: prayerType, status: status);
    return page;
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
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    }
    final records = _records.values
        .where((r) => r.userId == userId)
        .where((r) => prayerType == null || r.prayerType == prayerType)
        .where((r) => status == null || r.status == status)
        .where((r) => from == null || !r.originalDate.isBefore(from))
        .where((r) => to == null || !r.originalDate.isAfter(to))
        .where((r) =>
            afterOriginalDate == null ||
            r.originalDate.isAfter(afterOriginalDate) ||
            (r.originalDate.isAtSameMomentAs(afterOriginalDate) &&
                r.id.compareTo(afterId!) > 0))
        .toList()
      ..sort((a, b) {
        final d = a.originalDate.compareTo(b.originalDate);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final hasMore = records.length > limit;
    return QazaPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<List<QazaRecord>> _collectPages(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    final result = <QazaRecord>[];
    DateTime? date;
    String? id;
    while (true) {
      final page = await getPage(
          userId: userId,
          limit: 500,
          prayerType: prayerType,
          status: status,
          afterOriginalDate: date,
          afterId: id);
      result.addAll(page.records);
      if (!page.hasMore) return result;
      date = page.nextOriginalDate;
      id = page.nextId;
    }
  }

  @override
  Future<QazaRecord?> getOldestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await getPage(
        userId: userId,
        limit: 1,
        prayerType: prayerType,
        status: QazaStatus.pending);
    return page.records.isEmpty ? null : page.records.first;
  }

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
    historyPageCalls++;
    final records = _records.values
        .where((r) => r.userId == userId)
        .where((r) => prayerType == null || r.prayerType == prayerType)
        .where((r) => status == null || r.status == status)
        .where((r) => from == null || !r.originalDate.isBefore(from))
        .where((r) => to == null || !r.originalDate.isAfter(to))
        .where((r) =>
            beforeOriginalDate == null ||
            r.originalDate.isBefore(beforeOriginalDate) ||
            (r.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                r.id.compareTo(beforeId!) < 0))
        .toList()
      ..sort((a, b) {
        final d = b.originalDate.compareTo(a.originalDate);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
    final hasMore = records.length > limit;
    return QazaHistoryPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    progressSummaryCalls++;
    return QazaProgressSummary.fromRecords(
        _records.values.where((r) => r.userId == userId));
  }

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) {
      throw ArgumentError('from must be before to');
    }
    return _records.values
        .where((record) =>
            record.userId == userId && record.status == QazaStatus.completed)
        .where((record) {
      final completedAt = record.completedAt;
      return completedAt != null &&
          !completedAt.isBefore(from) &&
          completedAt.isBefore(to);
    }).length;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (!_storeAddRecord(record)) return;
    _recordChange(
      userId: record.userId,
      type: QazaRemoteChangeType.upsert,
      records: [record],
    );
  }

  bool _storeAddRecord(QazaRecord record) {
    if (_records.values.any((r) =>
        r.userId == record.userId &&
        r.prayerType == record.prayerType &&
        _sameDate(r.originalDate, record.originalDate))) {
      return false;
    }
    _records[record.id] = record;
    return true;
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    for (final record in records) {
      await addRecord(record);
    }
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
    final changed = <QazaRecord>[];
    for (final id in recordIds) {
      final r = _records[id];
      if (r == null || r.userId != userId) continue;
      if (r.status == QazaStatus.completed) {
        if (r.completedAt == null || completedAt.isBefore(r.completedAt!)) {
          final updated =
              r.copyWith(completedAt: completedAt, updatedAt: completedAt);
          _records[id] = updated;
          changed.add(updated);
        }
        continue;
      }
      final updated = r.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );
      _records[id] = updated;
      changed.add(updated);
    }
    if (changed.isNotEmpty) {
      _recordChange(
        userId: userId,
        type: QazaRemoteChangeType.complete,
        records: changed,
      );
    }
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    _resetWithoutChange(userId);
    final generation = _generations[userId] ?? 0;
    _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.reset,
      records: const <QazaRecord>[],
      generation: generation,
      idPrefix: 'reset',
    );
  }

  void _resetWithoutChange(String userId) {
    _records.removeWhere((_, record) => record.userId == userId);
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  @override
  Future<QazaRemoteResetState> getResetState({
    required String userId,
  }) async =>
      QazaRemoteResetState(
        generation: _generations[userId] ?? 0,
        inProgress: false,
      );

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  }) async {
    final changes = _changesByUser[userId];
    return changes == null || changes.isEmpty ? null : changes.last.cursor;
  }

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final changes = _changesByUser[userId] ?? const <QazaRemoteChange>[];
    final filtered = [
      for (final change in changes)
        if (after == null || _cursorAfter(change.cursor, after)) change,
    ];
    return QazaRemoteChangePage(
      changes: filtered.take(limit).toList(growable: false),
      hasMore: filtered.length > limit,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    if (operations.isEmpty) {
      throw ArgumentError('operations must not be empty');
    }
    for (final operation in operations) {
      if (operation.userId != userId) {
        throw StateError('operation belongs to another user');
      }
    }

    switch (operations.first.type) {
      case SyncOpType.add:
        final records = <QazaRecord>[];
        for (final operation in operations) {
          final record = operation.record;
          if (record == null) continue;
          _storeAddRecord(record);
          final stored = _records[record.id];
          if (stored != null) records.add(stored);
        }
        return _recordChange(
          userId: userId,
          type: QazaRemoteChangeType.upsert,
          records: records,
        );
      case SyncOpType.complete:
        await completeRecords(
          userId: userId,
          recordIds: [
            for (final operation in operations)
              if (operation.targetRecordId != null) operation.targetRecordId!,
          ],
          completedAt: operations.first.completedAt ?? DateTime.now(),
        );
        final latest = await getLatestChange(userId: userId);
        if (latest == null) {
          throw StateError('completion produced no remote change');
        }
        return latest;
      case SyncOpType.reset:
        throw ArgumentError('reset must use resetUserRecordsForSync');
    }
  }

  @override
  Future<void> deleteCloudData({required String userId}) async {
    _records.removeWhere((_, record) => record.userId == userId);
    _changesByUser.remove(userId);
  }

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) async {
    _resetWithoutChange(userId);
    final generation = (_generations[userId] ?? 0) + 1;
    _generations[userId] = generation;
    return _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.reset,
      records: const <QazaRecord>[],
      generation: generation,
      idPrefix: 'reset',
    );
  }

  bool _cursorAfter(
    QazaRemoteChangeCursor left,
    QazaRemoteChangeCursor right,
  ) {
    final at = left.at.compareTo(right.at);
    return at > 0 || (at == 0 && left.id.compareTo(right.id) > 0);
  }

  QazaRemoteChangeCursor _recordChange({
    required String userId,
    required QazaRemoteChangeType type,
    required List<QazaRecord> records,
    int? generation,
    String idPrefix = 'change',
  }) {
    _changeSequence++;
    final cursor = QazaRemoteChangeCursor(
      at: DateTime.utc(2026, 1, 1).add(
        Duration(microseconds: _changeSequence),
      ),
      id: '${idPrefix}-${_changeSequence.toString().padLeft(8, '0')}',
      generation: generation ?? (_generations[userId] ?? 0),
    );
    final change = QazaRemoteChange(
      type: type,
      cursor: cursor,
      records: List<QazaRecord>.unmodifiable(records),
    );
    (_changesByUser[userId] ??= <QazaRemoteChange>[]).add(change);
    return cursor;
  }

}
