import 'package:drift/drift.dart';

/// Normalized local representation of a Qaza prayer record.
///
/// Part 2 defines the schema only. Repository/DAO integration is intentionally
/// deferred to Part 3/4 so the existing SharedPreferences store remains the
/// active source of truth until the migration is complete.
class QazaRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text()();

  TextColumn get prayerType => text()();

  DateTimeColumn get originalDate => dateTime()();

  TextColumn get status => text()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId, prayerType, originalDate},
      ];
}
