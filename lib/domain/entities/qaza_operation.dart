import 'package:flutter/foundation.dart';

enum QazaOperationType {
  calculatorImport,
  rangeAdd,
  multipleDateAdd,
  singleDateAdd,

  /// Legacy persisted value. New writes use [singleDateAdd].
  manualAdd,

  bulkComplete,

  /// A single-record correction/deletion action. This is intentionally
  /// distinct from operation-level removal.
  singleRecordDelete,

  /// Legacy persisted value kept for backward compatibility.
  bulkDelete,

  restore,
}

enum QazaOperationStatus {
  running,
  completed,
  partial,
  undone,
  removed,
  failed,
}

@immutable
class QazaOperation {
  const QazaOperation({
    required this.operationId,
    required this.userId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.recordCount = 0,
    this.affectedRecordCount = 0,
    this.note,
    this.inputSnapshot,
  });

  final String operationId;
  final String userId;
  final QazaOperationType type;
  final QazaOperationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Immutable parameters captured when an addition operation starts.
  ///
  /// This is deliberately metadata, not a live form state. Future edit
  /// functionality can reconstruct an operation from this snapshot instead
  /// of guessing from mutated records.
  final Map<String, dynamic>? inputSnapshot;

  final int recordCount;
  final int affectedRecordCount;
  final String? note;

  bool get isAddition => switch (type) {
        QazaOperationType.calculatorImport ||
        QazaOperationType.rangeAdd ||
        QazaOperationType.multipleDateAdd ||
        QazaOperationType.singleDateAdd ||
        QazaOperationType.manualAdd =>
          true,
        _ => false,
      };

  QazaOperation copyWith({
    QazaOperationStatus? status,
    DateTime? updatedAt,
    int? recordCount,
    int? affectedRecordCount,
    String? note,
    Map<String, dynamic>? inputSnapshot,
    bool clearInputSnapshot = false,
  }) =>
      QazaOperation(
        operationId: operationId,
        userId: userId,
        type: type,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        recordCount: recordCount ?? this.recordCount,
        affectedRecordCount: affectedRecordCount ?? this.affectedRecordCount,
        note: note ?? this.note,
        inputSnapshot:
            clearInputSnapshot ? null : inputSnapshot ?? this.inputSnapshot,
      );

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'userId': userId,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'recordCount': recordCount,
        'affectedRecordCount': affectedRecordCount,
        'note': note,
        'inputSnapshot': inputSnapshot,
      };

  factory QazaOperation.fromJson(Map<String, dynamic> json) {
    return QazaOperation(
      operationId: json['operationId'] as String,
      userId: json['userId'] as String,
      type: _parseType(json['type'] as String?),
      status: QazaOperationStatus.values.firstWhere(
        (v) => v.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      affectedRecordCount: (json['affectedRecordCount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      inputSnapshot: json['inputSnapshot'] is Map
          ? Map<String, dynamic>.from(
              json['inputSnapshot'] as Map,
            )
          : null,
    );
  }

  static QazaOperationType _parseType(String? raw) {
    // Persisted installations may still contain the pre-rename manualAdd
    // value. Normalize it at the domain boundary so the rest of the app only
    // needs to reason about singleDateAdd.
    if (raw == 'manualAdd') return QazaOperationType.singleDateAdd;
    if (raw == null) {
      throw const FormatException('Missing Qaza operation type.');
    }
    return QazaOperationType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Unknown Qaza operation type: $raw'),
    );
  }
}
