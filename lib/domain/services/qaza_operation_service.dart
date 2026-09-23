import 'dart:math';

import '../entities/qaza_operation.dart';
import '../repositories/qaza_operation_repository.dart';

class QazaOperationService {
  QazaOperationService(this.repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final QazaOperationRepository repository;
  final DateTime Function() _now;

  String _newId(DateTime timestamp) =>
      'op_${timestamp.microsecondsSinceEpoch}_${Random().nextInt(1 << 30).toRadixString(36)}';

  Future<QazaOperation> begin({
    required String userId,
    required QazaOperationType type,
    Map<String, dynamic>? inputSnapshot,
  }) async {
    final timestamp = _now();
    final op = QazaOperation(
      operationId: _newId(timestamp),
      userId: userId,
      type: type,
      status: QazaOperationStatus.running,
      createdAt: timestamp,
      updatedAt: timestamp,
      inputSnapshot: inputSnapshot == null
          ? null
          : _freezeMap(inputSnapshot),
    );
    await repository.save(op);
    return op;
  }

  static Map<String, dynamic> _freezeMap(
    Map<String, dynamic> source,
  ) =>
      Map.unmodifiable({
        for (final entry in source.entries)
          entry.key: _freezeValue(entry.value),
      });

  static dynamic _freezeValue(dynamic value) {
    if (value is Map) {
      return Map.unmodifiable({
        for (final entry in value.entries)
          entry.key.toString(): _freezeValue(entry.value),
      });
    }
    if (value is Iterable) {
      return List.unmodifiable(
        value.map(_freezeValue),
      );
    }
    return value;
  }

  Future<QazaOperation> finish(
    QazaOperation operation, {
    required QazaOperationStatus status,
    required int affectedRecordCount,
    String? note,
  }) async {
    final existing = await repository.get(
      operation.userId,
      operation.operationId,
    );
    final recordCount = operation.recordCount != 0
        ? operation.recordCount
        : (existing?.recordCount ?? 0) != 0
            ? existing!.recordCount
            : affectedRecordCount;
    final finished = operation.copyWith(
        status: status,
        updatedAt: _now(),
        recordCount: recordCount,
        affectedRecordCount: affectedRecordCount,
        note: note,
      );
    await repository.save(finished);
    return finished;
  }

  Future<List<QazaOperation>> recent(String userId, {int limit = 50}) =>
      repository.listRecent(userId, limit: limit);
}