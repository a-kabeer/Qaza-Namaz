import 'package:drift/drift.dart';

/// Normalized local representation of a Qaza prayer record.
///
/// The domain model remains separate from Drift's generated row type so DAO
/// code can explicitly map persistence data into domain entities.
@DataClassName('QazaRecordRow')
class QazaRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text()();

  TextColumn get prayerType => text()();

  DateTimeColumn get originalDate => dateTime()();

  TextColumn get status => text()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get completionId => text().nullable()();
  TextColumn get additionId => text().nullable()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId, prayerType, originalDate},
      ];
}
