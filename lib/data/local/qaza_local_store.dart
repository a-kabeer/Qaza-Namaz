import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';

/// Remote operations the outbox can replay.
///
/// [reset] carries no payload: it deletes the whole remote ledger for its
/// user, so it supersedes every operation queued before it.
enum SyncOpType { add, complete, reset }

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
  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);

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
      ..removeWhere((r) => status != null && r.status != status)
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
      ..removeWhere((r) => status != null && r.status != status)
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
  Future<List<PendingSyncOp>> loadOutboxBatch(String userId,
      {int limit = 400}) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    final all = await loadOutbox(userId);
    return all.take(limit).toList(growable: false);
  }

  Future<void> removeOutboxBatch(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    final wanted = ids.toSet();
    final remaining = (await loadOutbox(userId))
        .where((op) => !wanted.contains(op.id))
        .toList(growable: false);
    await saveOutbox(userId, remaining);
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
      if (!wanted.contains(record.id) ||
          record.status == QazaStatus.completed) {
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

  /// Adds records without removing anything already stored.
  ///
  /// The default rewrites the user's rows because a plain store has no other
  /// way; database-backed stores override it with an insert.
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
