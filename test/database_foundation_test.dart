import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  test('AppDatabase opens at schema version 1', () async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    expect(database.schemaVersion, 1);
    expect(database.allTables, isEmpty);

    final rows = await database.customSelect('PRAGMA user_version').getSingle();
    expect(rows.read<int>('user_version'), 1);
  });

  test('AppDatabase accepts a standard Drift QueryExecutor', () async {
    final database = AppDatabase(NativeDatabase.memory());

    addTearDown(database.close);

    final result = await database.customSelect('SELECT 1 AS value').getSingle();
    expect(result.read<int>('value'), 1);
  });
}
