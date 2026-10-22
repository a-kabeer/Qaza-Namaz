import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';

void main() {
  test('shared workspace resolution reuses the control handle', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    await database.readDbRevision();
    await database.customStatement(
      "INSERT INTO local_accounts "
      "(local_account_id, created_at, updated_at) VALUES ('guest_test', 1, 1)",
    );

    final resolved = await manager.databaseForWorkspace('guest_test');
    expect(identical(resolved, database), isTrue);
    await manager.close();
  });

  test('unregistered workspace fails closed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    await database.readDbRevision();

    await expectLater(
      manager.databaseForWorkspace('google_not_registered'),
      throwsStateError,
    );
    await manager.close();
  });

  test('separate layout never silently falls back to shared database', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    await database.readDbRevision();
    await database.customStatement(
      "INSERT INTO local_accounts "
      "(local_account_id, db_file_name, db_layout, created_at, updated_at) "
      "VALUES ('google_example', 'qaza_google_example.sqlite', 'separate', 1, 1)",
    );

    await expectLater(
      manager.databaseForWorkspace('google_example'),
      throwsStateError,
    );
    await manager.close();
  });
}
