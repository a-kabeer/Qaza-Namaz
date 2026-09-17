import '../../domain/entities/qaza_record.dart';

/// Type of a queued remote operation in the offline outbox.
enum SyncOpType { add, complete }

/// A single pending remote operation waiting to be flushed to Firestore.
class PendingSyncOp {
  const PendingSyncOp({
    required this.id,
    required this.type,
    required this.userId,
    required this.queuedAt,
    this.record,
    this.targetRecordId,
    this.completedAt,
    this.attempts = 0,
    this.lastError,
  });

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
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'userId': userId,
        'queuedAt': queuedAt.toIso8601String(),
        'record': record?.toJson(),
        'targetRecordId': targetRecordId,
        'completedAt': completedAt?.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  static PendingSyncOp fromJson(Map<String, dynamic> json) => PendingSyncOp(
        id: json['id'] as String,
        type: SyncOpType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => throw StateError('Unknown sync op type "${json['type']}".'),
        ),
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
        lastError: json['lastError'] as String?,
      );
}

class OfflineCacheSnapshot {
  const OfflineCacheSnapshot({
    this.recordsByUser = const {},
    this.outboxByUser = const {},
    this.lastSyncByUser = const {},
  });

  final Map<String, List<QazaRecord>> recordsByUser;
  final Map<String, List<PendingSyncOp>> outboxByUser;
  final Map<String, DateTime> lastSyncByUser;
}

abstract interface class QazaLocalStore {
  Future<OfflineCacheSnapshot> load();
  Future<void> saveRecords(String userId, List<QazaRecord> records);
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops);
  Future<void> saveLastSync(String userId, DateTime? lastSync);

  /// Persists the complete local snapshot atomically when supported.
  ///
  /// Implementations that cannot provide a transaction fall back to the
  /// individual persistence operations. Drift uses one SQLite transaction.
  Future<void> saveRecordsAndOutbox(
    String userId,
    List<QazaRecord> records,
    List<PendingSyncOp> ops,
  ) async {
    await saveRecords(userId, records);
    await saveOutbox(userId, ops);
  }
}
