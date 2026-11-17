import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:drift/drift.dart' as drift;
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/powersync_config.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_signout_test_');
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = DatabaseEncryptionKeyStore();
    PowerSyncConfig.authorizeWorkspaceForTesting('google_signout_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    PowerSyncConfig.resetAuthorizedWorkspacesForTesting();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<({AppDatabase db, ps.PowerSyncDatabase psDb, String dbPath})>
      openWorkspace({required String workspaceId}) async {
    final encryptionKey = await keyStore.readOrCreate();
    final dbPath = await QazaPowerSyncDatabaseManager.resolveWorkspaceDatabasePath(
      workspaceId: workspaceId,
      documentsDirectoryProvider: () async => tempDir,
    );
    final psDb = await QazaPowerSyncDatabaseManager.getInstance(
      workspaceId: workspaceId,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
      keyStore: keyStore,
      documentsDirectoryProvider: () async => tempDir,
    );
    final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
      workspaceId: workspaceId,
      customPath: dbPath,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
    );
    final db = AppDatabase.forPowerSync(
      driftConn,
      workspaceId: workspaceId,
      role: AppDatabaseRole.googleWorkspace,
    );
    return (db: db, psDb: psDb, dbPath: dbPath);
  }

  test('Behavior of disconnectAndClear(clearLocal: true) on pending mutations and local records', () async {
    const wsId = 'google_signout_test';
    var ws = await openWorkspace(workspaceId: wsId);

    final now = DateTime.utc(2026, 9, 1);
    // 1. Insert Qaza record
    await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
      id: 'rec_signout_1',
      userId: wsId,
      prayerType: 'fajr',
      originalDate: now,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    ));

    // 2. Complete a prayer
    await ws.db.qazaRecordsDao.completeByIds(
      userId: wsId,
      ids: ['rec_signout_1'],
      completedAt: now,
    );

    // 3. Verify pending queue in ps_crud is non-empty
    final crudBefore = await ws.psDb.getAll('SELECT * FROM ps_crud');
    expect(crudBefore, isNotEmpty);

    // 4. Verify local qaza_records table has 1 record
    final recordsBefore = await ws.db.qazaRecordsDao.findById(userId: wsId, id: 'rec_signout_1');
    expect(recordsBefore, isNotNull);

    // 5. Explicitly test disconnectAndClear(clearLocal: true)
    await QazaPowerSyncDatabaseManager.disconnectAndClear(
      workspaceId: wsId,
      clearLocal: true,
      documentsDirectoryProvider: () async => tempDir,
    );

    // 6. Reopen the workspace
    final wsReopened = await openWorkspace(workspaceId: wsId);

    // 7. Check if local records survived (wiped by disconnectAndClear)
    final recordsAfter = await wsReopened.db.qazaRecordsDao.findById(userId: wsId, id: 'rec_signout_1');
    expect(recordsAfter, isNull);

    // 8. Check if ps_crud operations survived (wiped by disconnectAndClear)
    final crudAfter = await wsReopened.psDb.getAll('SELECT * FROM ps_crud');
    expect(crudAfter, isEmpty);

    await wsReopened.db.close();
  });

  test('Behavior of safe disconnect() without clearing on pending mutations and local records', () async {
    const wsId = 'google_signout_safe_test';
    var ws = await openWorkspace(workspaceId: wsId);

    final now = DateTime.utc(2026, 9, 1);
    await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
      id: 'rec_safe_1',
      userId: wsId,
      prayerType: 'fajr',
      originalDate: now,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    ));

    await ws.db.qazaRecordsDao.completeByIds(
      userId: wsId,
      ids: ['rec_safe_1'],
      completedAt: now,
    );

    // Verify pending queue before disconnect
    final crudBefore = await ws.psDb.getAll('SELECT * FROM ps_crud');
    expect(crudBefore, isNotEmpty);

    // Safe disconnect: disconnect stream and close database without clearLocal
    await QazaPowerSyncDatabaseManager.disconnect(workspaceId: wsId);
    await QazaPowerSyncDatabaseManager.closeDatabase(
      workspaceId: wsId,
      documentsDirectoryProvider: () async => tempDir,
    );

    // Reopen workspace
    final wsReopened = await openWorkspace(workspaceId: wsId);

    // Check if local records survived
    final recordsAfter = await wsReopened.db.qazaRecordsDao.findById(userId: wsId, id: 'rec_safe_1');
    expect(recordsAfter, isNotNull);

    // Check if ps_crud operations survived
    final crudAfter = await wsReopened.psDb.getAll('SELECT * FROM ps_crud');
    expect(crudAfter.length, equals(crudBefore.length));

    await wsReopened.db.close();
  });
}
