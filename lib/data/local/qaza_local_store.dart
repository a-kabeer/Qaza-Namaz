import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_activity.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../core/utils/qaza_completion_id.dart';

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
      this.completionId,
      this.attempts = 0,
      this.lastError});
  final String id;
  final SyncOpType type;
  final String userId;
  final DateTime queuedAt;
  final QazaRecord? record;
  final String? targetRecordId;
  final DateTime? completedAt;

  /// Completion marker carried by completion ops and expected by Undo ops.
  final String? completionId;
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
      completionId: completionId ?? completionId,
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
        'completionId': completionId,
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
      completionId: json['completionId'] as String?,
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

abstract class QazaLocalStore {
  Future<OfflineCacheSnapshot> load();
  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);

  /// Retires all local records and pending sync operations owned by [userId].
  ///
  /// This is intentionally user-scoped and atomic in database-backed stores.
  /// It is only called after an explicit destructive choice or a successful
  /// guest migration.
  Future<void> retireUserData({required String userId});

  Future<LocalQazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
    DateTime? beforeOriginalDate,
    String? beforeId,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    final originalCursor = afterOriginalDate != null || beforeOriginalDate != null;
    final completedCursor = afterCompletedAt != null || beforeCompletedAt != null;

    if ((afterOriginalDate != null) != (afterId != null) ||
        (beforeOriginalDate != null) != (beforeId != null) ||
        (afterOriginalDate != null && beforeOriginalDate != null) ||
        (afterCompletedAt != null && beforeCompletedAt != null) ||
        (completedCursor && originalCursor) ||
        (completedCursor && (afterId == null && beforeId == null)) ||
        (completedCursor && status != QazaStatus.completed)) {
      throw ArgumentError('Invalid pagination cursor');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }

    final snapshot = await load();
    var records = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
      ..removeWhere((r) => prayerType != null && r.prayerType != prayerType)
      ..removeWhere((r) =>
          prayerTypes != null && !prayerTypes.contains(r.prayerType))
      ..removeWhere((r) => status != null && r.status != status)
      ..removeWhere((r) => additionId != null && r.additionId != additionId)
      ..removeWhere((r) => from != null && r.originalDate.isBefore(from))
      ..removeWhere((r) => to != null && r.originalDate.isAfter(to));

    if (status == QazaStatus.completed) {
      records.sort((a, b) {
        final at = a.completedAt;
        final bt = b.completedAt;
        if (at == null && bt == null) return b.id.compareTo(a.id);
        if (at == null) return 1;
        if (bt == null) return -1;
        final d = bt.compareTo(at);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
      if (beforeCompletedAt != null) {
        records = records.where((r) {
          final value = r.completedAt;
          if (value == null) return false;
          return value.isBefore(beforeCompletedAt) ||
              (value.isAtSameMomentAs(beforeCompletedAt) &&
                  r.id.compareTo(beforeId!) < 0);
        }).toList();
      } else if (afterCompletedAt != null) {
        records = records.where((r) {
          final value = r.completedAt;
          if (value == null) return false;
          return value.isAfter(afterCompletedAt) ||
              (value.isAtSameMomentAs(afterCompletedAt) &&
                  r.id.compareTo(afterId!) > 0);
        }).toList();
      }
    } else {
      records.sort((a, b) {
        final d = descending
            ? b.originalDate.compareTo(a.originalDate)
            : a.originalDate.compareTo(b.originalDate);
        return d != 0
            ? d
            : (descending ? b.id.compareTo(a.id) : a.id.compareTo(b.id));
      });
      if (afterOriginalDate != null) {
        records = records
            .where((r) =>
                r.originalDate.isAfter(afterOriginalDate) ||
                (r.originalDate.isAtSameMomentAs(afterOriginalDate) &&
                    r.id.compareTo(afterId!) > 0))
            .toList();
      } else if (beforeOriginalDate != null) {
        records = records
            .where((r) =>
                r.originalDate.isBefore(beforeOriginalDate) ||
                (r.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                    r.id.compareTo(beforeId!) < 0))
            .toList();
      }
    }

    final hasMore = records.length > limit;
    return LocalQazaPage(
      records: records.take(limit).toList(growable: false),
      hasMore: hasMore,
    );
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

  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) async {
    final snapshot = await load();
    final wanted = ids.toSet();
    return [
      for (final record
          in snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        if (wanted.contains(record.id)) record,
    ];
  }

  /// Returns the minimal completion projection needed for activity history.
  /// Production Drift storage overrides this with a bounded SQLite query.
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    if (!from.isBefore(toExclusive)) {
      throw ArgumentError('from must be before toExclusive');
    }
    final snapshot = await load();
    final allowed = prayerTypes?.toSet();
    return (snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        .where((record) => record.status == QazaStatus.completed)
        .where((record) => allowed == null || allowed.contains(record.prayerType))
        .map((record) => record.completedAt == null
            ? null
            : QazaActivityRow(
                completedAt: record.completedAt!,
                prayerType: record.prayerType,
              ))
        .whereType<QazaActivityRow>()
        .where((row) => !row.completedAt.isBefore(from))
        .where((row) => row.completedAt.isBefore(toExclusive))
        .toList(growable: false);
  }

  /// Counts completions in [from, to) without materializing unrelated records.
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    final snapshot = await load();
    return (snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        .where((record) => record.status == QazaStatus.completed)
        .where((record) =>
            prayerTypes == null || prayerTypes.contains(record.prayerType))
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

  /// Bulk-write capability hook. Database-backed stores override this to
  /// return only records actually accepted by the database.
  Future<List<String>> appendRecordsAndOutboxReturningInsertedIds({
    required String userId,
    required List<QazaRecord> records,
    required List<PendingSyncOp> ops,
  }) async {
    await appendRecordsAndOutbox(userId, records, ops);
    return records.map((record) => record.id).toList(growable: false);
  }

  Future<List<PendingSyncOp>> loadOutbox(String userId) async {
    final snapshot = await load();
    return List<PendingSyncOp>.of(
        snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[]);
  }

  /// Marks only currently-pending records completed and returns the exact
  /// records that changed. Each id may carry its own completion marker.
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) async {
    if (recordIds.isEmpty) return const <QazaRecord>[];
    final snapshot = await load();
    final records = List<QazaRecord>.of(
      snapshot.recordsByUser[userId] ?? const <QazaRecord>[],
    );
    final wanted = recordIds.toSet();
    final changed = <QazaRecord>[];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (!wanted.contains(record.id) || record.status != QazaStatus.pending) {
        continue;
      }
      final marker = completionIds?[record.id] ?? newQazaCompletionId();
      if (marker.isEmpty) throw StateError('A completion marker is required.');

      final completed = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: marker,
        updatedAt: completedAt,
        recordVersion: record.recordVersion + 1,
      );
      records[index] = completed;
      changed.add(completed);
    }

    if (changed.isNotEmpty) await saveRecords(userId, records);
    return List.unmodifiable(changed);
  }

  /// Reverts only records whose completion marker still matches the active
  /// undo window. Server-side update timestamps are deliberately ignored.
  /// Restores matching completions and queues their sync operations.
  ///
  /// Database-backed stores override this so the state change and outbox write
  /// share one transaction.
  Future<List<QazaRecord>> undoCompletionsAndQueue({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    final changed = await undoCompletions(
      userId: userId,
      expectedCompletionIds: expectedCompletionIds,
      undoneAt: undoneAt,
    );
    if (changed.isEmpty) return changed;

    final operations = <PendingSyncOp>[
      for (final record in changed)
        PendingSyncOp(
          id: 'undo_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
          type: SyncOpType.update,
          userId: userId,
          queuedAt: record.updatedAt,
          targetRecordId: record.id,
          completionId: expectedCompletionIds[record.id],
          record: record,
        ),
    ];
    await appendRecordsAndOutbox(
      userId,
      const <QazaRecord>[],
      operations,
    );
    return changed;
  }

  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletionIds.isEmpty) return const <QazaRecord>[];
    final snapshot = await load();
    final records = List<QazaRecord>.of(
      snapshot.recordsByUser[userId] ?? const <QazaRecord>[],
    );
    final changed = <QazaRecord>[];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final expected = expectedCompletionIds[record.id];
      if (expected == null ||
          record.status != QazaStatus.completed ||
          record.completionId != expected) {
        continue;
      }

      final undone = record.copyWith(
        status: QazaStatus.pending,
        clearCompletedAt: true,
        clearCompletionId: true,
        updatedAt: undoneAt,
      );
      records[index] = undone;
      changed.add(undone);
    }

    if (changed.isNotEmpty) await saveRecords(userId, records);
    return changed;
  }

  /// Adds records without removing anything already stored.
  ///
  /// The default rewrites the user's rows because a plain store has no other
  /// way; database-backed stores override it with an insert.
  Future<void> upsertRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final snapshot = await load();
    final byId = <String, QazaRecord>{
      for (final record
          in snapshot.recordsByUser[userId] ?? const <QazaRecord>[])
        record.id: record,
    };
    for (final record in records) {
      if (record.userId == userId) {
        byId[record.id] = record;
      }
    }
    await saveRecords(userId, byId.values.toList(growable: false));
  }

  Future<void> appendRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final snapshot = await load();
    final existing = List<QazaRecord>.of(
        snapshot.recordsByUser[userId] ?? const <QazaRecord>[]);
    final known = {for (final record in existing) record.id};
    for (final record in records) {
      if (known.add(record.id)) existing.add(record);
    }
    await saveRecords(userId, existing);
  }

  Future<void> saveRecordsAndOutbox(
      String userId, List<QazaRecord> records, List<PendingSyncOp> ops) async {
    await saveRecords(userId, records);
    await saveOutbox(userId, ops);
  }
}
