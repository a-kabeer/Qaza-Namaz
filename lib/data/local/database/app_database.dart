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
          await customStatement(
            'CREATE INDEX qaza_records_user_date_idx '
            'ON qaza_records (user_id, original_date)',
          );
          await customStatement(
            'CREATE INDEX qaza_records_user_prayer_date_idx '
            'ON qaza_records (user_id, prayer_type, original_date)',
          );
          await customStatement(
            'CREATE INDEX qaza_records_user_prayer_status_date_idx '
            'ON qaza_records '
            '(user_id, prayer_type, status, original_date)',
          );
          await customStatement(
            'CREATE INDEX qaza_records_user_status_completed_idx '
            'ON qaza_records (user_id, status, completed_at)',
          );
        },
      );
}
