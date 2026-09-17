import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  test('AppDatabase opens at schema version 2', () async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    expect(database.schemaVersion, 2);
    expect(database.allTables, isEmpty);

    final rows = await database.customSelect('PRAGMA user_version').getSingle();
    expect(rows.read<int>('user_version'), 2);
  });

  test('AppDatabase creates all required performance indexes', () async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'index' AND name IN ("
      "'qaza_records_user_date_idx',"
      "'qaza_records_user_prayer_date_idx',"
      "'qaza_records_user_prayer_status_date_idx',"
      "'qaza_records_user_status_completed_idx',"
      "'sync_outbox_user_queued_idx',"
      "'sync_outbox_user_type_idx'"
      ') ORDER BY name',
    ).get();

    expect(
      rows.map((row) => row.read<String>('name')).toList(),
      containsAll(<String>[
        'qaza_records_user_date_idx',
        'qaza_records_user_prayer_date_idx',
        'qaza_records_user_prayer_status_date_idx',
        'qaza_records_user_status_completed_idx',
        'sync_outbox_user_queued_idx',
        'sync_outbox_user_type_idx',
      ]),
    );
  });

  test('AppDatabase accepts a standard Drift QueryExecutor', () async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    final result = await database.customSelect('SELECT 1 AS value').getSingle();
    expect(result.read<int>('value'), 1);
  });
}
