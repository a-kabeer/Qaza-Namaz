import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';

/// Type of a queued remote operation in the offline outbox.
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

  static PendingSyncOp fromJson(Map<String, dynamic> json) => PendingSyncOp(
        id: json['id'] as String,
        type: SyncOpType.values.firstWhere((value) => value.name == json['type'], orElse: () => throw StateError('Unknown sync op type "${json['type']}".')),
        userId: json['userId'] as String,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
        record: json['record'] == null ? null : QazaRecord.fromJson(json['record'] as Map<String, dynamic>),
        targetRecordId: json['targetRecordId'] as String?,
        completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['lastError'] as String?,
      );
}

class OfflineCacheSnapshot {
  const OfflineCacheSnapshot({this.recordsByUser = const {}, this.outboxByUser = const {}, this.lastSyncByUser = const {}});
  final Map<String, List<QazaRecord>> recordsByUser;
  final Map<String, List<PendingSyncOp>> outboxByUser;
  final Map<String, DateTime> lastSyncByUser;
}

/// A bounded page returned by the local source of truth.
class LocalQazaPage {
  const LocalQazaPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate => records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

/// A bounded newest-first history page.
class LocalQazaHistoryPage {
  const LocalQazaHistoryPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate => records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

abstract interface class QazaLocalStore {
  Future<OfflineCacheSnapshot> load();
  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);

  Future<LocalQazaPage> getPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status, DateTime? afterOriginalDate, String? afterId}) async {
    final snapshot = await load();
    var records = snapshot.recordsByUser[userId] ?? const <QazaRecord>[];
    records = records.where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).toList()
      ..sort((a, b) {
        final date = a.originalDate.compareTo(b.originalDate);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
    if (afterOriginalDate != null && afterId != null) {
      records = records.where((r) => r.originalDate.isAfter(afterOriginalDate) || (r.originalDate.isAtSameMomentAs(afterOriginalDate) && r.id.compareTo(afterId) > 0)).toList();
    }
    final hasMore = records.length > limit;
    return LocalQazaPage(records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<LocalQazaHistoryPage> getHistoryPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status = QazaStatus.completed, DateTime? from, DateTime? to, DateTime? beforeOriginalDate, String? beforeId}) async {
    final snapshot = await load();
    var records = snapshot.recordsByUser[userId] ?? const <QazaRecord>[];
    records = records.where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).where((r) => from == null || !r.originalDate.isBefore(from)).where((r) => to == null || !r.originalDate.isAfter(to)).toList()
      ..sort((a, b) {
        final date = b.originalDate.compareTo(a.originalDate);
        return date != 0 ? date : b.id.compareTo(a.id);
      });
    if (beforeOriginalDate != null && beforeId != null) {
      records = records.where((r) => r.originalDate.isBefore(beforeOriginalDate) || (r.originalDate.isAtSameMomentAs(beforeOriginalDate) && r.id.compareTo(beforeId) < 0)).toList();
    }
    final hasMore = records.length > limit;
    return LocalQazaHistoryPage(records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<void> saveRecordsAndOutbox(String userId, List<QazaRecord> records, List<PendingSyncOp> ops) async {
    await saveRecords(userId, records);
    await saveOutbox(userId, ops);
  }
}
