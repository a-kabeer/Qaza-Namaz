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
  }) async {
    final timestamp = _now();
    final op = QazaOperation(
      operationId: _newId(timestamp),
      userId: userId,
      type: type,
      status: QazaOperationStatus.running,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await repository.save(op);
    return op;
  }

  Future<void> finish(
    QazaOperation operation, {
    required QazaOperationStatus status,
    required int affectedRecordCount,
    String? note,
  }) => repository.save(operation.copyWith(
        status: status,
        updatedAt: _now(),
        recordCount: operation.recordCount == 0
            ? affectedRecordCount
            : operation.recordCount,
        affectedRecordCount: affectedRecordCount,
        note: note,
      ));

  Future<List<QazaOperation>> recent(String userId, {int limit = 50}) =>
      repository.listRecent(userId, limit: limit);
}
