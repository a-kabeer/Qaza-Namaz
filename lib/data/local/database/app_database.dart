import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/qaza_records.dart';

part 'app_database.g.dart';

/// Application-local SQLite database.
///
/// Part 2 introduces the normalized Qaza schema. The existing
/// SharedPreferences store remains the active production store until the
/// repository and migration work is completed in later parts.
@DriftDatabase(tables: [QazaRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'qaza_namaz'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );
}
