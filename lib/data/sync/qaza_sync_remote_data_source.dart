import '../../domain/entities/qaza_record.dart';
import '../local/qaza_local_store.dart';

enum QazaRemoteChangeType { upsert, update, complete, delete, reset }

class QazaRemoteChangeCursor {
  const QazaRemoteChangeCursor({
    required this.at,
    required this.id,
    required this.generation,
  });

  final DateTime at;
  final String id;
  final int generation;
}

class QazaRemoteChange {
  const QazaRemoteChange({
    required this.type,
    required this.cursor,
    required this.records,
    this.recordIds = const <String>[],
  });

  final QazaRemoteChangeType type;
  final QazaRemoteChangeCursor cursor;
  final List<QazaRecord> records;
  final List<String> recordIds;
}

class QazaRemoteChangePage {
  const QazaRemoteChangePage({
    required this.changes,
    required this.hasMore,
  });

  final List<QazaRemoteChange> changes;
  final bool hasMore;

  QazaRemoteChangeCursor? get nextCursor =>
      changes.isEmpty ? null : changes.last.cursor;
}

class QazaRemoteResetState {
  const QazaRemoteResetState({
    required this.generation,
    required this.inProgress,
  });

  final int generation;
  final bool inProgress;
}

abstract interface class QazaSyncRemoteDataSource {
  Future<QazaRemoteResetState> getResetState({required String userId});

  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  });

  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  });

  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  });

  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  });

  /// Permanently removes the user's cloud records and cloud change log while
  /// leaving the local/offline ledger untouched.
  Future<void> deleteCloudData({required String userId});

}
