import '../entities/qaza_operation.dart';

abstract interface class QazaOperationRepository {
  Future<void> save(QazaOperation operation);
  Future<QazaOperation?> get(String userId, String operationId);
  Future<List<QazaOperation>> listRecent(String userId, {int limit = 50});
  Future<void> delete(String userId, String operationId);
}
