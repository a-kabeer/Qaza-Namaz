import 'package:drift/drift.dart';

/// Normalized local representation of a Qaza prayer record.
///
/// The domain model remains separate from Drift's generated row type so DAO
/// code can explicitly map persistence data into domain entities.
@DataClassName('QazaRecordRow')
class QazaRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text()();

  TextColumn get operationId => text().nullable()();

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
