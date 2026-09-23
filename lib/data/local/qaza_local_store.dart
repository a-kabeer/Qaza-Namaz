import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_recovery_repository.dart';

/// Remote operations the outbox can replay.
///
/// [reset] carries no payload: it deletes the whole remote ledger for its
/// user, so it supersedes every operation queued before it.
enum SyncOpType { add, update, complete, delete, reset }

class PendingSyncOp {
  const PendingSyncOp(
      {required this.id,
      required this.type,
      required this.userId,
      required this.queuedAt,
      this.record,
      this.targetRecordId,
      this.completedAt,
      this.attempts = 0,
      this.lastError});
  final String id;
  final SyncOpType type;
  final String userId;
  final DateTime queuedAt;
  final QazaRecord? record;
  final String? targetRecordId;
  final DateTime? completedAt;
  final int attempts;
  final String? lastError;
  PendingSyncOp copyWith({int? attempts, String? lastError}) => PendingSyncOp(
      id: id,
      type: type,
      userId: userId,
      queuedAt: queuedAt,
      record: record,
      targetRecordId: targetRecordId,
      completedAt: completedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError);
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'userId': userId,
        'queuedAt': queuedAt.toIso8601String(),
        'record': record?.toJson(),
        'targetRecordId': targetRecordId,
        'completedAt': completedAt?.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError
      };
  static PendingSyncOp fromJson(Map<String, dynamic> json) => PendingSyncOp(
      id: json['id'] as String,
      type: SyncOpType.values.firstWhere((value) => value.name == json['type'],
          orElse: () =>
              throw StateError('Unknown sync op type "${json['type']}".')),
      userId: json['userId'] as String,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      record: json['record'] == null
          ? null
          : QazaRecord.fromJson(json['record'] as Map<String, dynamic>),
      targetRecordId: json['targetRecordId'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?);
}

class OfflineCacheSnapshot {
  const OfflineCacheSnapshot(
      {this.recordsByUser = const {},
      this.outboxByUser = const {},
      this.lastSyncByUser = const {}});
  final Map<String, List<QazaRecord>> recordsByUser;
  final Map<String, List<PendingSyncOp>> outboxByUser;
  final Map<String, DateTime> lastSyncByUser;
}

class LocalQazaPage {
  const LocalQazaPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

class LocalQazaHistoryPage {
  const LocalQazaHistoryPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

abstract class QazaLocalStore {
  Future<OfflineCacheSnapshot> load();
  /// Operation summaries are aggregate data. Database-backed stores override
  /// this with a SQL query; the fallback remains correct for lightweight stores.
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) async {
    final snapshot = await load();
    final records =
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[];
    var pending = 0;
    var completed = 0;
    var deleted = 0;
    var unchangedPending = 0;
    for (final record in records) {
      if (record.operationId != operationId) continue;
      switch (record.status) {
        case QazaStatus.pending:
          pending++;
          if (record.createdAt.isAtSameMomentAs(record.updatedAt)) {
            unchangedPending++;
          }
        case QazaStatus.completed:
          completed++;
        case QazaStatus.deleted:
          deleted++;
      }
    }
    return QazaOperationSummary(
      pending: pending,
      completed: completed,
      deleted: deleted,
      unchangedPending: unchangedPending,
    );
  }

  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);
  /// Bounded keyset page for soft-deleted records, ordered by deletion time.
  /// Operation-scoped pagination. Unlike normal History reads, a null
  /// status intentionally includes soft-deleted records so Operation Details
  /// can present a complete lifecycle without changing global query semantics.
  Future<LocalQazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError(
          'beforeOriginalDate and beforeId must be provided together');
    }

    final snapshot = await load();
    var records = List<QazaRecord>.of(
      snapshot.recordsByUser[userId] ?? const <QazaRecord>[],
    )..removeWhere((record) {
        final actionMatch = matchLastAction
            ? record.updatedAt.isAtSameMomentAs(operationAt)
            : record.operationId == operationId;
        final statusMatch = status == null || record.status == status;
        return !actionMatch || !statusMatch;
      });

    records.sort((a, b) {
      final date = b.originalDate.compareTo(a.originalDate);
      return date != 0 ? date : b.id.compareTo(a.id);
    });

    if (beforeOriginalDate != null) {
      records = records.where((record) {
        return record.originalDate.isBefore(beforeOriginalDate!) ||
            (record.originalDate.isAtSameMomentAs(beforeOriginalDate!) &&
                record.id.compareTo(beforeId!) < 0);
      }).toList();
    }

    final hasMore = records.length > limit;
    return LocalQazaPage(
      records: records.take(limit).toList(growable: false),
      hasMore: hasMore,
    );
  }

  Future<LocalQazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((beforeDeletedAt == null) != (beforeId == null)) {
      throw ArgumentError(
          'beforeDeletedAt and beforeId must be provided together');
    }
    final snapshot = await load();
    var records = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
      ..removeWhere((r) => r.status != QazaStatus.deleted)
      ..sort((a, b) {
        final d = b.updatedAt.compareTo(a.updatedAt);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
    if (beforeDeletedAt != null) {
      records = records
          .where((r) =>
              r.updatedAt.isBefore(beforeDeletedAt) ||
              (r.updatedAt.isAtSameMomentAs(beforeDeletedAt) &&
                  r.id.compareTo(beforeId!) < 0))
          .toList();
    }
    final hasMore = records.length > limit;
    return LocalQazaHistoryPage(
      records: records.take(limit).toList(growable: false),
      hasMore: hasMore,
    );
  }



  /// Retires all local records and pending sync operations owned by [userId].
  ///
  /// This is intentionally user-scoped and atomic in database-backed stores.
  /// It is only called after an explicit destructive choice or a successful
  /// guest migration.
  Future<void> retireUserData({required String userId});

  Future<LocalQazaPage> getPage(
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
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
    final snapshot = await load();
    var records = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
      ..removeWhere((r) => prayerType != null && r.prayerType != prayerType)
      ..removeWhere((r) => status == QazaStatus.deleted
          ? r.status != QazaStatus.deleted
          : r.status == QazaStatus.deleted ||
              (status != null && r.status != status))
      ..removeWhere((r) => from != null && r.originalDate.isBefore(from))
      ..removeWhere((r) => to != null && r.originalDate.isAfter(to))
      ..sort((a, b) {
        final d = a.originalDate.compareTo(b.originalDate);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    if (afterOriginalDate != null) {
      records = records
          .where((r) =>
              r.originalDate.isAfter(afterOriginalDate) ||
              (r.originalDate.isAtSameMomentAs(afterOriginalDate) &&
                  r.id.compareTo(afterId!) > 0))
          .toList();
    }
    final hasMore = records.length > limit;
    return LocalQazaPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<QazaRecord?> getOldestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await getPage(
        userId: userId,
        limit: 1,
        prayerType: prayerType,
        status: QazaStatus.pending);
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<LocalQazaHistoryPage> getHistoryPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status = QazaStatus.completed,
      DateTime? from,
      DateTime? to,
      DateTime? beforeOriginalDate,
      String? beforeId}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError(
          'beforeOriginalDate and beforeId must be provided together');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
    final snapshot = await load();
    var records = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
      ..removeWhere((r) => prayerType != null && r.prayerType != prayerType)
      ..removeWhere((r) => status == QazaStatus.deleted
          ? r.status != QazaStatus.deleted
          : r.status == QazaStatus.deleted ||
              (status != null && r.status != status))
      ..removeWhere((r) => from != null && r.originalDate.isBefore(from))
      ..removeWhere((r) => to != null && r.originalDate.isAfter(to))
      ..sort((a, b) {
        final d = b.originalDate.compareTo(a.originalDate);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
    if (beforeOriginalDate != null) {
      records = records
          .where((r) =>
              r.originalDate.isBefore(beforeOriginalDate) ||
              (r.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                  r.id.compareTo(beforeId!) < 0))
          .toList();
    }
    final hasMore = records.length > limit;
    return LocalQazaHistoryPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) async {
    final snapshot = await load();
    final wanted = ids.toSet();
    return [
      for (final record in snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        if (wanted.contains(record.id)) record,
    ];
  }

  /// Counts completions in [from, to) without materializing unrelated records.
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshot = await load();
    return (snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        .where((record) => record.status == QazaStatus.completed)
        .where((record) {
      final completedAt = record.completedAt;
      return completedAt != null &&
          !completedAt.isBefore(from) &&
          completedAt.isBefore(to);
    }).length;
  }

  Future<bool> hasRecordCombination({
    required String userId,
    required PrayerType prayerType,
    required DateTime originalDate,
    String? excludingRecordId,
  }) async {
    final snapshot = await load();
    return (snapshot.recordsByUser[userId] ?? const <QazaRecord>[]).any(
      (record) =>
          record.prayerType == prayerType &&
          record.originalDate.year == originalDate.year &&
          record.originalDate.month == originalDate.month &&
          record.originalDate.day == originalDate.day &&
          record.id != excludingRecordId,
    );
  }

  Future<bool> updateRecord(QazaRecord record) async {
    final snapshot = await load();
    final records = List<QazaRecord>.of(
      snapshot.recordsByUser[record.userId] ?? const <QazaRecord>[],
    );
    final index = records.indexWhere((candidate) => candidate.id == record.id);
    if (index < 0) return false;
    records[index] = record;
    await saveRecords(record.userId, records);
    return true;
  }

  Future<bool> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    final snapshot = await load();
    final records = List<QazaRecord>.of(
      snapshot.recordsByUser[userId] ?? const <QazaRecord>[],
    );
    final before = records.length;
    records.removeWhere((record) => record.id == recordId);
    if (records.length == before) return false;
    await saveRecords(userId, records);
    return true;
  }

  Future<bool> updateRecordAndOutbox({
    required String userId,
    required QazaRecord record,
    required PendingSyncOp operation,
  }) async {
    final changed = await updateRecord(record);
    if (!changed) return false;
    await appendRecordsAndOutbox(
      userId,
      const <QazaRecord>[],
      [operation],
    );
    return true;
  }

  Future<bool> deleteRecordAndOutbox({
    required String userId,
    required String recordId,
    required PendingSyncOp operation,
  }) async {
    final changed = await deleteRecord(
      userId: userId,
      recordId: recordId,
    );
    if (!changed) return false;
    await appendRecordsAndOutbox(
      userId,
      const <QazaRecord>[],
      [operation],
    );
    return true;
  }

  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    final snapshot = await load();
    return QazaProgressSummary.fromRecords(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[]);
  }

  /// True when a [SyncOpType.reset] is still queued for [userId].
  ///
  /// Bootstrap consults this before hydrating: an empty local ledger that is
  /// empty *because the user reset it* must not be refilled from the cloud
  /// copy the queued reset is about to delete.
  Future<bool> hasPendingReset(String userId) async {
    final snapshot = await load();
    return (snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[])
        .any((op) => op.type == SyncOpType.reset);
  }

  /// The queued operations for one user.
  ///
  /// Separate from [load] so a completion can bring the queue up to date
  /// without reading the ledger it is deliberately not touching.
  Future<int> countPendingOutbox(String userId) async =>
      (await loadOutbox(userId)).length;

  Future<List<PendingSyncOp>> loadOutboxBatch(String userId,
      {int limit = 400}) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    final all = await loadOutbox(userId);
    return all.take(limit).toList(growable: false);
  }

  Future<void> markOutboxBatchRetry({
    required String userId,
    required List<String> ids,
    required String error,
  }) async {
    final wanted = ids.toSet();
    final current = await loadOutbox(userId);
    final next = [
      for (final op in current)
        if (wanted.contains(op.id))
          op.copyWith(attempts: op.attempts + 1, lastError: error)
        else
          op,
    ];
    await saveOutbox(userId, next);
  }

  Future<void> removeOutboxBatch(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    final wanted = ids.toSet();
    final remaining = (await loadOutbox(userId))
        .where((op) => !wanted.contains(op.id))
        .toList(growable: false);
    await saveOutbox(userId, remaining);
  }

  Future<void> upsertRecordsAndOutbox({
    required String userId,
    required List<QazaRecord> records,
    required List<PendingSyncOp> ops,
  }) async {
    await upsertRecords(userId, records);
    await appendRecordsAndOutbox(userId, const <QazaRecord>[], ops);
  }

  Future<void> appendRecordsAndOutbox(
      String userId, List<QazaRecord> records, List<PendingSyncOp> ops) async {
    await appendRecords(userId, records);
    await saveOutbox(userId, [...await loadOutbox(userId), ...ops]);
  }

  Future<List<PendingSyncOp>> loadOutbox(String userId) async {
    final snapshot = await load();
    return List<PendingSyncOp>.of(
        snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[]);
  }

  /// Marks records completed without touching the rest of the ledger.
  ///
  /// Returns the ids actually changed: one already completed is left alone.
  /// The default implementation is correct but reads the snapshot; stores
  /// backed by a database override it with a targeted update.
  Future<List<String>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    final snapshot = await load();
    final records = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[]);
    final wanted = recordIds.toSet();
    final changed = <String>[];
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (!wanted.contains(record.id)) continue;
      if (record.status == QazaStatus.completed &&
          record.completedAt != null &&
          !completedAt.isBefore(record.completedAt!)) {
        continue;
      }
      records[index] = record.copyWith(
          status: QazaStatus.completed,
          completedAt: completedAt,
          updatedAt: completedAt);
      changed.add(record.id);
    }
    if (changed.isNotEmpty) await saveRecords(userId, records);
    return changed;
  }

  /// Reverts only records whose completion timestamp and last update
  /// still match the completion captured by the active undo window.
  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletedAt.isEmpty) return const <QazaRecord>[];
    final snapshot = await load();
    final records = List<QazaRecord>.of(
      snapshot.recordsByUser[userId] ?? const <QazaRecord>[],
    );
    final changed = <QazaRecord>[];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final expected = expectedCompletedAt[record.id];
      if (expected == null ||
          record.status != QazaStatus.completed ||
          record.completedAt == null ||
          !record.completedAt!.isAtSameMomentAs(expected) ||
          !record.updatedAt.isAtSameMomentAs(expected)) {
        continue;
      }

      final undone = record.copyWith(
        status: QazaStatus.pending,
        completedAt: null,
        updatedAt: undoneAt,
      );
      records[index] = undone;
      changed.add(undone);
    }

    if (changed.isNotEmpty) await saveRecords(userId, records);
    return changed;