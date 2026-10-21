import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/src/phase1_backup_bridge.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  test(
    'scoped Phase 1 validation rejects records owned by another workspace',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);
      await store.ensureInitialized();

      const workspaceId = 'google_bridge-test-account';
      await store.ensureAccountActive(workspaceId);
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'google_bridge-test-account_fajr_2026-10-01',
          userId: workspaceId,
          prayerType: 'fajr',
          originalDate: DateTime(2026, 10, 1),
          status: 'pending',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );

      final source = LocalPhase1BackupSource(
        database,
        localAccountId: workspaceId,
      );
      final validBackup = await source.exportBackup();
      await source.validateBackup(validBackup);

      final decoded = jsonDecode(validBackup) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final records = data['qaza_records'] as List<dynamic>;
      records.single['userId'] = 'google_some-other-account';

      await expectLater(
        source.validateBackup(jsonEncode(decoded)),
        throwsA(isA<Exception>()),
      );

      // Validation is read-only: it must not switch the active workspace or
      // mutate existing Qaza records.
      expect(await database.readActiveLocalAccountId(), workspaceId);
      expect(
        (await database.qazaRecordsDao.getAll(
          userId: workspaceId,
        )).map((record) => record.id),
        ['google_bridge-test-account_fajr_2026-10-01'],
      );
    },
  );
}
