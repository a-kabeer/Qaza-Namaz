import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/entities/qaza_ledger_summary.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';

enum SyncOpType { add, complete }

class PendingSyncOp {
  const PendingSyncOp({required this.id, required this.type, required this.userId, required this.queuedAt, this.record, this.targetRecordId, this.completedAt, this.attempts = 0, this.lastError});
  final String id;
  final SyncOpType type;
  final String userId;
  final DateTime queuedAt;
  final QazaRecord? record;
  final String? targetRecordId;
  final DateTime? completedAt;
  final int attempts;
  final String? lastError;
  PendingSyncOp copyWith({int? attempts, String? lastError}) => PendingSyncOp(id: id, type: type, userId: userId, queuedAt: queuedAt, record: record, targetRecordId: targetRecordId, completedAt: completedAt, attempts: attempts ?? this.attempts, lastError: lastError ?? this.lastError);
  Map<String, dynamic> toJson() => {'id': id, 'type': type.name, 'userId': userId, 'queuedAt': queuedAt.toIso8601String(), 'record': record?.toJson(), 'targetRecordId': targetRecordId, 'completedAt': completedAt?.toIso8601String(), 'attempts': attempts, 'lastError': lastError};
  static PendingSyncOp fromJson(Map<String, dynamic> json) => PendingSyncOp(id: json['id'] as String, type: SyncOpType.values.firstWhere((value) => value.name == json['type']), userId: json['userId'] as String, queuedAt: DateTime.parse(json['queuedAt'] as String), record: json['record'] == null ? null : QazaRecord.fromJson(json['record'] as Map<String, dynamic>), targetRecordId: json['targetRecordId'] as String?, completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String), attempts: (json['attempts'] as num?)?.toInt() ?? 0, lastError: json['lastError'] as String?);
}

class OfflineCacheSnapshot {
  const OfflineCacheSnapshot({this.recordsByUser = const {}, this.outboxByUser = const {}, this.lastSyncByUser = const {}});
  final Map<String, List<QazaRecord>> recordsByUser;
  final Map<String, List<PendingSyncOp>> outboxByUser;
  final Map<String, DateTime> lastSyncByUser;
}

abstract interface class QazaLocalStore {
  Future<OfflineCacheSnapshot> load();
  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);

  /// Incremental outbox operations. Database-backed stores should implement
  /// these without loading the complete queue.
  Future<int> getPendingSyncCount(String userId) async => (await load()).outboxByUser[userId]?.length ?? 0;
  Future<PendingSyncOp?> getNextPendingSyncOp(String userId) async {
    final ops = (await load()).outboxByUser[userId] ?? const <PendingSyncOp>[];
    return ops.isEmpty ? null : ops.first;
  }
  Future<bool> hasPendingCompletion(String userId, String recordId) async {
    final ops = (await load()).outboxByUser[userId] ?? const <PendingSyncOp>[];
    return ops.any((op) => op.type == SyncOpType.complete && op.targetRecordId == recordId);
  }
  Future<void> deletePendingSyncOp(String userId, String opId) async {
    final ops = List<PendingSyncOp>.of((await load()).outboxByUser[userId] ?? const <PendingSyncOp>[])
      ..removeWhere((op) => op.id == opId);
    await saveOutbox(userId, ops);
  }
  Future<void> updatePendingSyncOp(String userId, PendingSyncOp op) async {
    final ops = List<PendingSyncOp>.of((await load()).outboxByUser[userId] ?? const <PendingSyncOp>[]);
    final index = ops.indexWhere((item) => item.id == op.id);
    if (index >= 0) ops[index] = op;
    else ops.add(op);
    await saveOutbox(userId, ops);
  }

  Future<List<QazaRecord>> getRecordsForDates({required String userId, required Iterable<DateTime> dates, PrayerType? prayerType, QazaStatus? status}) async {
    final wanted = dates.map((date) => DateTime(date.year, date.month, date.day)).toSet();
    if (wanted.isEmpty) return const [];
    final records = (await load()).recordsByUser[userId] ?? const <QazaRecord>[];
    return records.where((record) {
      final date = DateTime(record.originalDate.year, record.originalDate.month, record.originalDate.day);
      return wanted.contains(date) && (prayerType == null || record.prayerType == prayerType) && (status == null || record.status == status);
    }).toList(growable: false);
  }

  Future<QazaLedgerSummary> getSummary(String userId) async {
    final records = (await load()).recordsByUser[userId] ?? const <QazaRecord>[];
    final byPrayer = <PrayerType, QazaProgress>{};
    for (final prayer in PrayerType.values) {
      final prayerRecords = records.where((r) => r.prayerType == prayer);
      byPrayer[prayer] = QazaProgress(pending: prayerRecords.where((r) => r.status == QazaStatus.pending).length, completed: prayerRecords.where((r) => r.status == QazaStatus.completed).length);
    }
    final pending = records.where((r) => r.status == QazaStatus.pending).length;
    final completed = records.where((r) => r.status == QazaStatus.completed).length;
    return QazaLedgerSummary(total: records.length, pending: pending, completed: completed, byPrayer: byPrayer);
  }

  Future<QazaHistoryPage> getHistoryPage({required String userId, PrayerType? prayerType, QazaStatus? status, DateTime? originalDateFrom, DateTime? originalDateTo, String? cursor, int limit = 25, bool ascending = false}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    final snapshot = await load();
    var records = List<QazaRecord>.of(snapshot.recordsByUser[userId] ?? const []);
    records = records.where((r) { final date = DateTime(r.originalDate.year, r.originalDate.month, r.originalDate.day); return (prayerType == null || r.prayerType == prayerType) && (status == null || r.status == status) && (originalDateFrom == null || !date.isBefore(originalDateFrom)) && (originalDateTo == null || !date.isAfter(originalDateTo)); }).toList()..sort((a, b) { final byDate = ascending ? a.originalDate.compareTo(b.originalDate) : b.originalDate.compareTo(a.originalDate); return byDate != 0 ? byDate : a.id.compareTo(b.id); });
    var start = 0;
    if (cursor != null) { final index = records.indexWhere((r) => r.id == cursor); if (index >= 0) start = index + 1; }
    if (start >= records.length) return const QazaHistoryPage(records: []);
    final end = (start + limit).clamp(0, records.length);
    final page = records.sublist(start, end);
    return QazaHistoryPage(records: List.unmodifiable(page), nextCursor: end < records.length ? page.last.id : null);
  }
}