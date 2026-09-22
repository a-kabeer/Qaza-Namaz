import 'package:flutter/foundation.dart';

enum QazaOperationType {
  calculatorImport,
  rangeAdd,
  multipleDateAdd,
  manualAdd,
  bulkComplete,
  bulkDelete,
  restore,
}

enum QazaOperationStatus { running, completed, partial, undone, failed }

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
  });

  final String operationId;
  final String userId;
  final QazaOperationType type;
  final QazaOperationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int recordCount;
  final int affectedRecordCount;
  final String? note;

  QazaOperation copyWith({
    QazaOperationStatus? status,
    DateTime? updatedAt,
    int? recordCount,
    int? affectedRecordCount,
    String? note,
  }) => QazaOperation(
    operationId: operationId,
    userId: userId,
    type: type,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    recordCount: recordCount ?? this.recordCount,
    affectedRecordCount: affectedRecordCount ?? this.affectedRecordCount,
    note: note ?? this.note,
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
  };

  factory QazaOperation.fromJson(Map<String, dynamic> json) {
    return QazaOperation(
      operationId: json['operationId'] as String,
      userId: json['userId'] as String,
      type: QazaOperationType.values.firstWhere(
        (v) => v.name == json['type'],
      ),
      status: QazaOperationStatus.values.firstWhere(
        (v) => v.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      affectedRecordCount: (json['affectedRecordCount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
    );
  }
}
