import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  group('CloudSyncEngine', () {
    test(
      'first connection with a remote backup requires an explicit decision',
      () async {
        final phase1 = FakePhase1(revision: 1);
        final state = FakeState(deviceIdValue: 'device-B', cursor: null);
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-existing',
            baseBackupId: null,
            revision: 9,
            modifiedAt: DateTime.utc(2026, 10, 9),
            remoteVersion: '1',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.conflict);
        expect(
          state.pendingConflict!.remoteLineage.backupId,
          'backup-existing',
        );
        expect(phase1.importCount, 0);
        expect(remote.writeCount, 0);
      },
    );

    test('disabled cloud state prevents remote reads and writes', () async {
      final phase1 = FakePhase1(revision: 10);
      final state = FakeState(
        deviceIdValue: 'device-A',
        cursor: null,
        cloudEnabled: false,
      );
      final remote = FakeRemote(latestSnapshot: null);

      final result = await CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      ).sync();

      expect(result.kind, CloudSyncResultKind.skipped);
      expect(remote.latestCount, 0);
      expect(remote.writeCount, 0);
    });

    test(
      'uploads the initial local backup when no remote backup exists',
      () async {
        final phase1 = FakePhase1(revision: 10);
        final state = FakeState(deviceIdValue: 'device-A', cursor: null);
        final remote = FakeRemote(latestSnapshot: null);

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.uploaded);
        expect(remote.writeCount, 1);
        expect(remote.written!.lineage.baseBackupId, isNull);
        expect(remote.written!.lineage.dbRevision, 10);
        expect(
          state.cursor!.lastSyncedBackupId,
          remote.written!.lineage.backupId,
        );
        expect(state.cursor!.lastSyncedLocalRevision, 10);
      },
    );

    test('different device IDs alone do not create a conflict', () async {
      final phase1 = FakePhase1(revision: 10);
      final state = FakeState(
        deviceIdValue: 'device-B',
        cursor: const CloudSyncCursor(
          lastSyncedLocalRevision: 10,
          lastSyncedBackupId: 'backup-100',
          lastSyncedRemoteVersion: '1',
        ),
      );
      final remote = FakeRemote(
        latestSnapshot: _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-100',
          baseBackupId: null,
          revision: 3,
          modifiedAt: DateTime.utc(2026, 10, 8),
          remoteVersion: '1',
        ),
      );

      final result = await CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      ).sync();

      expect(result.kind, CloudSyncResultKind.noOp);
      expect(phase1.importCount, 0);
      expect(remote.writeCount, 0);
    });

    test(
      'local-only progression uploads with the last remote backup as base',
      () async {
        final phase1 = FakePhase1(revision: 11);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-100',
            baseBackupId: null,
            revision: 10,
            modifiedAt: DateTime.utc(2026, 10, 8),
            remoteVersion: '1',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.uploaded);
        expect(remote.writeCount, 1);
        expect(remote.written!.lineage.baseBackupId, 'backup-100');
        expect(remote.written!.lineage.dbRevision, 11);
        expect(
          state.cursor!.lastSyncedBackupId,
          remote.written!.lineage.backupId,
        );
      },
    );

    test(
      'remote-only progression downloads without using revision as cloud identity',
      () async {
        final phase1 = FakePhase1(revision: 10);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-101',
            baseBackupId: 'backup-100',
            revision: 3,
            modifiedAt: DateTime.utc(2026, 10, 9),
            remoteVersion: '2',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.downloaded);
        expect(phase1.importCount, 1);
        expect(phase1.saveRecoveryCount, 1);
        expect(phase1.recoverySnapshot, isNotNull);
        expect(state.cursor!.lastSyncedBackupId, 'backup-101');
      },
    );

    test(
      'remote-only restore is cancelled when recovery snapshot cannot be verified',
      () async {
        final phase1 = FakePhase1(revision: 10, hideRecoverySnapshot: true);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-101',
            baseBackupId: 'backup-100',
            revision: 11,
            modifiedAt: DateTime.utc(2026, 10, 9),
            remoteVersion: '2',
          ),
        );

        await expectLater(
          CloudSyncEngine(phase1: phase1, remote: remote, state: state).sync(),
          throwsA(isA<CloudAdapterException>()),
        );

        expect(phase1.saveRecoveryCount, 1);
        expect(phase1.importCount, 0);
        expect(state.cursor!.lastSyncedBackupId, 'backup-100');
      },
    );

    test(
      'remote-only restore surfaces a conflict if latest remote changes during snapshot',
      () async {
        final phase1 = FakePhase1(revision: 10);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final initial = _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-101',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9),
          remoteVersion: '2',
        );
        final latest = _snapshot(
          deviceId: 'device-C',
          backupId: 'backup-102',
          baseBackupId: 'backup-101',
          revision: 12,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 1),
          remoteVersion: '3',
        );
        final remote = FakeRemote(
          latestSnapshot: initial,
          latestSnapshots: <CloudRemoteSnapshot?>[initial, latest],
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.conflict);
        expect(result.conflict!.remoteLineage.backupId, 'backup-102');
        expect(state.pendingConflict!.remoteLineage.backupId, 'backup-102');
        expect(phase1.saveRecoveryCount, 1);
        expect(phase1.importCount, 0);
      },
    );

    test(
      'remote-only restore recomputes if local progress changes during snapshot',
      () async {
        final phase1 = FakePhase1(
          revision: 10,
          bumpRevisionWhenSavingRecovery: true,
        );
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-101',
            baseBackupId: 'backup-100',
            revision: 11,
            modifiedAt: DateTime.utc(2026, 10, 9),
            remoteVersion: '2',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        expect(result.kind, CloudSyncResultKind.conflict);
        expect(phase1.saveRecoveryCount, 1);
        expect(phase1.importCount, 0);
        expect(state.pendingConflict!.remoteLineage.backupId, 'backup-101');
      },
    );

    test('local unsynced plus remote changed returns a conflict', () async {
      final phase1 = FakePhase1(revision: 12);
      final state = FakeState(
        deviceIdValue: 'device-B',
        cursor: const CloudSyncCursor(
          lastSyncedLocalRevision: 10,
          lastSyncedBackupId: 'backup-100',
          lastSyncedRemoteVersion: '1',
        ),
      );
      final remote = FakeRemote(
        latestSnapshot: _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-102',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
          remoteVersion: '3',
        ),
      );

      final result = await CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      ).sync();

      expect(result.kind, CloudSyncResultKind.conflict);
      expect(result.conflict!.remoteLineage.backupId, 'backup-102');
      expect(result.conflict!.localRevision, 12);
      expect(result.conflict!.remoteLineage.deviceId, 'device-A');
      expect(result.conflict!.lastSyncedBackupId, 'backup-100');
      expect(phase1.importCount, 0);
    });

    test(
      'conflict exposes display information for user confirmation',
      () async {
        final phase1 = FakePhase1(revision: 12);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-102',
            baseBackupId: 'backup-100',
            revision: 11,
            modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
            remoteVersion: '3',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).sync();

        final display = result.conflict!.toDisplayData();
        expect(display['local_originating_device'], 'device-B');
        expect(display['remote_originating_device'], 'device-A');
        expect(display['local_revision'], 12);
        expect(display['remote_revision'], 11);
        expect(display['remote_backup_id'], 'backup-102');
        expect(display['remote_base_backup_id'], 'backup-100');
      },
    );

    test(
      'use-remote choice is rejected if local progress changes during snapshot',
      () async {
        final phase1 = FakePhase1(
          revision: 12,
          bumpRevisionWhenSavingRecovery: true,
        );
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final remote = FakeRemote(
          latestSnapshot: _snapshot(
            deviceId: 'device-A',
            backupId: 'backup-102',
            baseBackupId: 'backup-100',
            revision: 11,
            modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
            remoteVersion: '3',
          ),
        );

        final result = await CloudSyncEngine(
          phase1: phase1,
          remote: remote,
          state: state,
        ).resolveConflict(
          conflict: _conflict(remote),
          decision: CloudConflictDecision.useRemote,
          confirmed: true,
        );

        expect(result.kind, CloudSyncResultKind.conflict);
        expect(phase1.saveRecoveryCount, 1);
        expect(phase1.importCount, 0);
        expect(state.pendingConflict!.remoteLineage.backupId, 'backup-102');
      },
    );

    test(
      'stale remote conflict is refreshed instead of applying old decision',
      () async {
        final phase1 = FakePhase1(revision: 12);
        final state = FakeState(
          deviceIdValue: 'device-B',
          cursor: const CloudSyncCursor(
            lastSyncedLocalRevision: 10,
            lastSyncedBackupId: 'backup-100',
            lastSyncedRemoteVersion: '1',
          ),
        );
        final staleRemote = _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-102',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
          remoteVersion: '3',
        );
        final latestRemote = _snapshot(
          deviceId: 'device-C',
          backupId: 'backup-103',
          baseBackupId: 'backup-102',
          revision: 13,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 6),
          remoteVersion: '4',
        );
        final remote = FakeRemote(
          latestSnapshot: staleRemote,
          latestSnapshots: <CloudRemoteSnapshot?>[latestRemote],
        );

        final result =
            await CloudSyncEngine(
              phase1: phase1,
              remote: remote,
              state: state,
            ).resolveConflict(
              conflict: _conflict(FakeRemote(latestSnapshot: staleRemote)),
              decision: CloudConflictDecision.useRemote,
              confirmed: true,
            );

        expect(result.kind, CloudSyncResultKind.conflict);
        expect(result.conflict!.remoteLineage.backupId, 'backup-103');
        expect(state.pendingConflict!.remoteLineage.backupId, 'backup-103');
        expect(phase1.importCount, 0);
        expect(phase1.saveRecoveryCount, 0);
      },
    );

    test('conflict resolution requires explicit confirmation', () async {
      final phase1 = FakePhase1(revision: 12);
      final state = FakeState(
        deviceIdValue: 'device-B',
        cursor: const CloudSyncCursor(
          lastSyncedLocalRevision: 10,
          lastSyncedBackupId: 'backup-100',
          lastSyncedRemoteVersion: '1',
        ),
      );
      final remote = FakeRemote(
        latestSnapshot: _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-102',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
          remoteVersion: '3',
        ),
      );

      final engine = CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      );

      expect(
        () => engine.resolveConflict(
          conflict: _conflict(remote),
          decision: CloudConflictDecision.useRemote,
          confirmed: false,
        ),
        throwsA(isA<CloudAdapterException>()),
      );
      expect(phase1.importCount, 0);
    });

    test('use remote explicitly imports and advances local cursor', () async {
      final phase1 = FakePhase1(revision: 12);
      final state = FakeState(
        deviceIdValue: 'device-B',
        cursor: const CloudSyncCursor(
          lastSyncedLocalRevision: 10,
          lastSyncedBackupId: 'backup-100',
          lastSyncedRemoteVersion: '1',
        ),
      );
      final remote = FakeRemote(
        latestSnapshot: _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-102',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
          remoteVersion: '3',
        ),
      );

      final engine = CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      );

      final result = await engine.resolveConflict(
        conflict: _conflict(remote),
        decision: CloudConflictDecision.useRemote,
        confirmed: true,
      );

      expect(result.kind, CloudSyncResultKind.downloaded);
      expect(phase1.importCount, 1);
      expect(phase1.saveRecoveryCount, 1);
      expect(state.cursor!.lastSyncedBackupId, 'backup-102');
      expect(state.cursor!.lastSyncedLocalRevision, 13);
    });

    test('keep local publishes a new cloud version based on remote', () async {
      final phase1 = FakePhase1(revision: 12);
      final state = FakeState(
        deviceIdValue: 'device-B',
        cursor: const CloudSyncCursor(
          lastSyncedLocalRevision: 10,
          lastSyncedBackupId: 'backup-100',
          lastSyncedRemoteVersion: '1',
        ),
      );
      final remote = FakeRemote(
        latestSnapshot: _snapshot(
          deviceId: 'device-A',
          backupId: 'backup-102',
          baseBackupId: 'backup-100',
          revision: 11,
          modifiedAt: DateTime.utc(2026, 10, 9, 0, 5),
          remoteVersion: '3',
        ),
      );

      final result =
          await CloudSyncEngine(
            phase1: phase1,
            remote: remote,
            state: state,
          ).resolveConflict(
            conflict: _conflict(remote),
            decision: CloudConflictDecision.keepLocal,
            confirmed: true,
          );

      expect(result.kind, CloudSyncResultKind.uploaded);
      expect(remote.written!.lineage.baseBackupId, 'backup-102');
      expect(remote.written!.lineage.deviceId, 'device-B');
      expect(remote.written!.lineage.dbRevision, 12);
      expect(phase1.importCount, 0);
    });
  });
}

CloudConflict _conflict(FakeRemote remote) {
  final snapshot = remote.latestSnapshot!;
  return CloudConflict(
    localDeviceId: 'device-B',
    localTimestamp: DateTime.utc(2026, 10, 9),
    localRevision: 12,
    localBaseBackupId: 'backup-100',
    remoteLineage: snapshot.backup.lineage,
    remoteTimestamp: snapshot.modifiedAt,
    remoteVersion: snapshot.remoteVersion,
    lastSyncedBackupId: 'backup-100',
  );
}

CloudRemoteSnapshot _snapshot({
  required String deviceId,
  required String backupId,
  required String? baseBackupId,
  required int revision,
  required DateTime modifiedAt,
  required String remoteVersion,
}) {
  return CloudRemoteSnapshot(
    fileId: 'file-' + backupId,
    remoteVersion: remoteVersion,
    modifiedAt: modifiedAt,
    backup: CloudBackup(
      lineage: CloudLineage(
        deviceId: deviceId,
        backupId: backupId,
        baseBackupId: baseBackupId,
        dbRevision: revision,
        createdAt: modifiedAt,
      ),
      phase1BackupJson:
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":$revision},"data":{}}',
    ),
  );
}

class FakePhase1 implements Phase1BackupSource {
  FakePhase1({
    required int revision,
    this.hideRecoverySnapshot = false,
    this.bumpRevisionWhenSavingRecovery = false,
  }) : _revision = revision;

  final bool hideRecoverySnapshot;
  final bool bumpRevisionWhenSavingRecovery;

  int _revision;
  int importCount = 0;
  int saveRecoveryCount = 0;
  String? recoverySnapshot;

  @override
  Future<int> readDbRevision() async => _revision;

  @override
  Future<String> exportBackup() async =>
      '''
{
  "metadata": {
    "app_id": "qaza_namaz_app",
    "db_revision": $_revision,
    "export_timestamp": "2026-10-09T00:00:00.000Z"
  },
  "data": {}
}
''';

  @override
  Future<void> importBackup(String phase1BackupJson) async {
    importCount++;
    _revision++;
  }

  @override
  Future<void> saveRecoverySnapshot(String phase1BackupJson) async {
    saveRecoveryCount++;
    recoverySnapshot = phase1BackupJson;
    if (bumpRevisionWhenSavingRecovery) _revision++;
  }

  @override
  Future<String?> readRecoverySnapshot() async =>
      hideRecoverySnapshot ? null : recoverySnapshot;

  @override
  Future<void> clearRecoverySnapshot() async {
    recoverySnapshot = null;
  }
}

class FakeState implements CloudSyncStateStore {
  FakeState({
    required this.deviceIdValue,
    required this.cursor,
    this.cloudEnabled = true,
    this.automaticEnabled = true,
  });

  final String deviceIdValue;
  CloudSyncCursor? cursor;
  bool cloudEnabled;
  bool automaticEnabled;
  DateTime? lastSuccessfulAt;
  CloudConflict? pendingConflict;

  @override
  Future<String> deviceId() async => deviceIdValue;

  @override
  Future<CloudSyncCursor> readCursor() async =>
      cursor ?? const CloudSyncCursor.empty();

  @override
  Future<void> writeCursor(CloudSyncCursor cursor) async {
    this.cursor = cursor;
  }

  @override
  Future<bool> isCloudSyncEnabled() async => cloudEnabled;

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    cloudEnabled = enabled;
    if (!enabled) automaticEnabled = false;
  }

  @override
  Future<bool> isAutomaticSyncEnabled() async => automaticEnabled;

  @override
  Future<void> setAutomaticSyncEnabled(bool enabled) async {
    if (enabled && !cloudEnabled) {
      throw const CloudAdapterException('cloud disabled');
    }
    automaticEnabled = enabled;
  }

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async => lastSuccessfulAt;

  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) async {
    lastSuccessfulAt = value;
  }

  @override
  Future<CloudConflict?> readPendingConflict() async => pendingConflict;

  @override
  Future<void> writePendingConflict(CloudConflict conflict) async {
    pendingConflict = conflict;
  }

  @override
  Future<void> clearPendingConflict() async {
    pendingConflict = null;
  }
}

class FakeRemote implements CloudRemoteStore {
  FakeRemote({required this.latestSnapshot, this.latestSnapshots});

  CloudRemoteSnapshot? latestSnapshot;
  final List<CloudRemoteSnapshot?>? latestSnapshots;
  CloudBackup? written;
  int writeCount = 0;
  int latestCount = 0;

  @override
  Future<CloudRemoteSnapshot?> latest({required bool allowInteractive}) async {
    latestCount++;
    if (latestSnapshots != null && latestSnapshots!.isNotEmpty) {
      latestSnapshot = latestSnapshots!.removeAt(0);
    }
    return latestSnapshot;
  }

  @override
  Future<CloudRemoteSnapshot> write(
    CloudBackup backup, {
    required bool allowInteractive,
  }) async {
    writeCount++;
    written = backup;
    latestSnapshot = CloudRemoteSnapshot(
      fileId: 'file-' + backup.lineage.backupId,
      remoteVersion: 'new-version',
      modifiedAt: backup.lineage.createdAt,
      backup: backup,
    );
    return latestSnapshot!;
  }
}
