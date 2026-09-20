import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/sync_outbox.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  Future<List<SyncOutboxData>> getPendingBatch({
    required String userId,
    int limit = 400,
  }) {
    return (select(syncOutbox)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.queuedAt),
            (row) => OrderingTerm.asc(row.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<SyncOutboxData>> getPending({required String userId}) {
    return (select(syncOutbox)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.queuedAt),
            (row) => OrderingTerm.asc(row.id),
          ]))
        .get();
  }

  Future<List<String>> userIds() async {
    final query = selectOnly(syncOutbox, distinct: true)
      ..addColumns([syncOutbox.userId]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(syncOutbox.userId)!)
        .toList(growable: false);
  }

  Future<int> countPending({required String userId}) async {
    final query = selectOnly(syncOutbox)
      ..addColumns([syncOutbox.id.count()])
      ..where(syncOutbox.userId.equals(userId));
    return (await query.getSingle()).read(syncOutbox.id.count()) ?? 0;
  }

  /// True when an operation of [type] is still queued for [userId].
  ///
  /// Bounded to a single row so startup never materializes the outbox.
  Future<bool> hasPending(
      {required String userId, required String type}) async {
    final row = await (select(syncOutbox)
          ..where((row) => row.userId.equals(userId) & row.type.equals(type))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> put(SyncOutboxCompanion entry) async {
    await into(syncOutbox).insertOnConflictUpdate(entry);
  }

  Future<void> putAll(List<SyncOutboxCompanion> entries) async {
    if (entries.isEmpty) return;
    await transaction(() async {
      for (final entry in entries) {
        await into(syncOutbox).insertOnConflictUpdate(entry);
      }
    });
  }

  Future<int> remove({required String userId, required String id}) {
    return (delete(syncOutbox)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .go();
  }

  Future<int> markBatchRetry({
    required String userId,
    required List<String> ids,
    required String error,
  }) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      var updated = 0;
      for (final id in ids.toSet()) {
        updated += await (update(syncOutbox)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(id)))
            .write(
          SyncOutboxCompanion(
            attempts: const Value.absent(),
            lastError: Value(error),
          ),
        );
        await (update(syncOutbox)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(id)))
            .write(
          SyncOutboxCompanion(
            attempts: Value.custom('attempts + 1'),
          ),
        );
      }
      return updated;
    });
  }

  Future<int> removeBatch({
    required String userId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      var removed = 0;
      for (final id in ids.toSet()) {
        removed += await (delete(syncOutbox)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(id)))
            .go();
      }
      return removed;
    });
  }

  Future<int> removeAll({required String userId}) {
    return (delete(syncOutbox)..where((row) => row.userId.equals(userId))).go();
  }
}
