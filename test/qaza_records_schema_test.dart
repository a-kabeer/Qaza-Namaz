import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  test('creates Qaza schema with constraints and indexes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final columns = await database.customSelect('PRAGMA table_info(qaza_records)').get();
    expect(columns.map((row) => row.read<String>('name')), containsAll(<String>[
      'id',
      'user_id',
      'prayer_type',
      'original_date',
      'status',
      'completed_at',
      'created_at',
      'updated_at',
    ]));

    final indexes = await database.customSelect('PRAGMA index_list(qaza_records)').get();
    final indexNames = indexes.map((row) => row.read<String>('name')).toList();
    expect(indexNames, contains('qaza_records_user_date_idx'));
    expect(indexNames, contains('qaza_records_user_prayer_date_idx'));
    expect(indexNames, contains('qaza_records_user_prayer_status_date_idx'));
    expect(indexNames, contains('qaza_records_user_status_completed_idx'));

    await database.customInsert(
      'INSERT INTO qaza_records '
      '(id, user_id, prayer_type, original_date, status, completed_at, created_at, updated_at) '
      "VALUES ('1', 'user-a', 'fajr', '2026-01-01T00:00:00.000Z', 'pending', NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')",
    );

    expect(
      () => database.customInsert(
        'INSERT INTO qaza_records '
        '(id, user_id, prayer_type, original_date, status, completed_at, created_at, updated_at) '
        "VALUES ('2', 'user-a', 'fajr', '2026-01-01T00:00:00.000Z', 'pending', NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
