import 'package:drift/drift.dart';

/// Durable queue for remote synchronization operations.
///
/// Each row is independently retryable and user-scoped. Record payloads are
/// stored as JSON so the outbox can survive app restarts without depending on
/// the in-memory repository cache.
class SyncOutbox extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text()();

  TextColumn get type => text()();

  DateTimeColumn get queuedAt => dateTime()();

  TextColumn get recordJson => text().nullable()();

  TextColumn get targetRecordId => text().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
