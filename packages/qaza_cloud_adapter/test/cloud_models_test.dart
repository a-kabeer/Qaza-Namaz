import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  group('CloudLineage', () {
    test('round trips lineage metadata', () {
      final original = CloudLineage(
        deviceId: 'device-A',
        backupId: 'backup-123',
        baseBackupId: 'backup-100',
        dbRevision: 101,
        createdAt: DateTime.utc(2026, 10, 9, 0, 0),
      );

      final decoded = CloudLineage.fromJson(original.toJson());

      expect(decoded.deviceId, original.deviceId);
      expect(decoded.backupId, original.backupId);
      expect(decoded.baseBackupId, original.baseBackupId);
      expect(decoded.dbRevision, original.dbRevision);
      expect(decoded.createdAt, original.createdAt);
    });

    test('cloud wrapping preserves the Phase 1 payload semantically', () {
      const phase1 =
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":101},"data":{}}';
      final backup = CloudBackup(
        lineage: CloudLineage(
          deviceId: 'device-A',
          backupId: 'backup-123',
          baseBackupId: null,
          dbRevision: 101,
          createdAt: DateTime.utc(2026, 10, 9),
        ),
        phase1BackupJson: phase1,
      );

      final decoded =
          jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      expect(decoded['cloud_schema_version'], cloudSchemaVersion);
      expect(decoded['lineage']['backup_id'], 'backup-123');
      expect(decoded['phase1_backup']['metadata']['app_id'], 'qaza_namaz_app');

      final restored = CloudBackup.fromJsonString(backup.toJsonString());
      expect(jsonDecode(restored.phase1BackupJson), jsonDecode(phase1));
    });

    test('rejects a cloud lineage revision that disagrees with Phase 1', () {
      const cloud = '''
{
  "cloud_schema_version": 1,
  "lineage": {
    "device_id": "device-A",
    "backup_id": "backup-123",
    "base_backup_id": null,
    "db_revision": 101,
    "created_at": "2026-10-09T00:00:00.000Z"
  },
  "phase1_backup": {
    "metadata": {
      "app_id": "qaza_namaz_app",
      "db_revision": 100
    },
    "data": {}
  }
}
''';

      expect(
        () => CloudBackup.fromJsonString(cloud),
        throwsA(isA<CloudRemoteFormatException>()),
      );
    });
  });

  group('CloudSyncCursor', () {
    test('serializes the requested sync cursor fields', () {
      const cursor = CloudSyncCursor(
        lastSyncedLocalRevision: 101,
        lastSyncedBackupId: 'backup-123',
        lastSyncedRemoteVersion: '7',
      );

      final decoded = CloudSyncCursor.fromJson(cursor.toJson());

      expect(decoded.lastSyncedLocalRevision, 101);
      expect(decoded.lastSyncedBackupId, 'backup-123');
      expect(decoded.lastSyncedRemoteVersion, '7');
    });
  });
}
