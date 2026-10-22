import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';

void main() {
  late Directory directory;
  late AppDatabase control;
  late DatabaseManager manager;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qaza-db-manager-');
    control = AppDatabase(
      NativeDatabase(File('${directory.path}/control.sqlite')),
    );
    manager = DatabaseManager(
      controlDatabase: control,
      documentsDirectoryProvider: () async => directory,
      googleDatabaseFactory: ({
        required String fileName,
        required String workspaceId,
      }) => GoogleWorkspaceDatabase.forTesting(
        executor: NativeDatabase(File('${directory.path}/$fileName')),
        workspaceId: workspaceId,
      ),
    );
    await control.readDbRevision();
  });

  tearDown(() async {
    await manager.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Future<void> registerGuest(String id) async {
    await control.customStatement(
      'INSERT INTO local_accounts '
      '(local_account_id, created_at, updated_at) VALUES (?, 1, 1)',
      [Variable<String>(id)],
    );
  }

  Future<void> insertRecord(AppDatabase db, {
    required String id,
    required String owner,
  }) async {
    await db.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable<String>(id),
        Variable<String>(owner),
        const Variable<String>('fajr'),
        const Variable<int>(1),
        const Variable<String>('pending'),
        const Variable<int>(1),
        const Variable<int>(1),
      ],
    );
  }

  test('Guest workspace resolves to the existing control handle', () async {
    await registerGuest('guest_test');
    final resolved = await manager.databaseForWorkspace('guest_test');
    expect(identical(resolved, control), isTrue);
  });

  test('unregistered Google workspace fails closed', () async {
    await expectLater(
      manager.databaseForWorkspace('google_not_registered'),
      throwsStateError,
    );
  });

  test('separate layout never silently falls back to the control database',
      () async {
    final fileName =
        DatabaseManager.googleFileNameForWorkspaceId('google_example');
    await control.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, db_file_name, db_layout, db_migration_state,
          created_at, updated_at)
         VALUES (?, ?, 'separate', 'committed', 1, 1)''',
      variables: [
        const Variable<String>('google_example'),
        Variable<String>(fileName),
      ],
    );

    await expectLater(
      manager.databaseForWorkspace('google_example'),
      throwsStateError,
    );
    expect(await File('${directory.path}/$fileName').exists(), isFalse);
  });

  test('filename hashes stable Google ID without embedding account PII', () {
    const stableId = 'stable-id-that-is-not-an-email';
    final fileName =
        DatabaseManager.googleFileNameForWorkspaceId('google_$stableId');
    final hash = sha256.convert(utf8.encode(stableId)).toString();
    expect(fileName, 'qaza_google_${hash.substring(0, 32)}.sqlite');
    expect(fileName, isNot(contains(stableId)));
    expect(fileName, matches(RegExp(r'^qaza_google_[0-9a-f]{32}\.sqlite$')));
  });

  test('two Google accounts have different databases and data is isolated',
      () async {
    final first = await manager.ensureGoogleWorkspace('google_stable_a');
    final second = await manager.ensureGoogleWorkspace('google_stable_b');

    expect(identical(first, second), isFalse);
    expect(await first.readWorkspaceFileOwner(), 'google_stable_a');
    expect(await second.readWorkspaceFileOwner(), 'google_stable_b');

    await insertRecord(
      first,
      id: 'record_a',
      owner: 'google_stable_a',
    );

    final firstCount = await first.customSelect(
      'SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = ?',
      variables: [const Variable<String>('google_stable_a')],
    ).get();
    final secondCount = await second.customSelect(
      'SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = ?',
      variables: [const Variable<String>('google_stable_b')],
    ).get();
    expect(firstCount.single.read<int>('row_count'), 1);
    expect(secondCount.single.read<int>('row_count'), 0);

    await expectLater(
      insertRecord(
        first,
        id: 'foreign_record',
        owner: 'google_stable_b',
      ),
      throwsA(anything),
    );
  });

  test('concurrent provisioning returns one handle and one committed journal',
      () async {
    final handles = await Future.wait([
      manager.ensureGoogleWorkspace('google_concurrent'),
      manager.ensureGoogleWorkspace('google_concurrent'),
    ]);
    expect(identical(handles[0], handles[1]), isTrue);
    final rows = await control.customSelect(
      '''SELECT COUNT(*) AS row_count FROM workspace_operation_journal
         WHERE operation_id = 'google-workspace-create:google_concurrent'
           AND phase = 'committed' ''',
    ).get();
    expect(rows.single.read<int>('row_count'), 1);
  });

  test('legacy shared Google data is preserved and not silently replaced',
      () async {
    await control.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES ('google_legacy', 'local', 'active', 1, 1)''',
    );
    await insertRecord(
      control,
      id: 'legacy_record',
      owner: 'google_legacy',
    );

    await expectLater(
      manager.ensureGoogleWorkspace('google_legacy'),
      throwsStateError,
    );
    final preserved = await control.customSelect(
      "SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = 'google_legacy'",
    ).get();
    expect(preserved.single.read<int>('row_count'), 1);
    final fileName =
        DatabaseManager.googleFileNameForWorkspaceId('google_legacy');
    expect(await File('${directory.path}/$fileName').exists(), isFalse);
  });
}
