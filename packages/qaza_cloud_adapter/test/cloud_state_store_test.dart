import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatic backup cadence supports all selectable frequencies', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 1)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 7)),
      const Duration(days: 7),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 30)),
      const Duration(days: 30),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cloud and automatic sync default to disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isFalse);
    expect(await state.hasAutomaticSyncPreference(), isFalse);
    expect(await state.backupFrequency(), CloudBackupFrequency.daily);
    expect(await state.isReconnectRequired(), isFalse);
    expect(await state.lastSuccessfulSyncAt(), isNull);
  });

  test('disabling cloud preserves the saved automatic backup choice', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');

    await state.setCloudSyncEnabled(true);
    await state.setAutomaticSyncEnabled(true);
    await state.setReconnectRequired(true);
    await state.writeCursor(
      const CloudSyncCursor(
        lastSyncedLocalRevision: 7,
        lastSyncedBackupId: 'existing-backup',
        lastSyncedRemoteVersion: 'existing-version',
      ),
    );
    await state.writePendingConflict(_conflict('existing-conflict'));
    expect(await state.isAutomaticSyncEnabled(), isTrue);
    expect(await state.isReconnectRequired(), isTrue);

    await state.setCloudSyncEnabled(false);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isTrue);
    expect(await state.isReconnectRequired(), isFalse);
    expect(
      await state.readCursor(),
      const CloudSyncCursor(
        lastSyncedLocalRevision: 7,
        lastSyncedBackupId: 'existing-backup',
        lastSyncedRemoteVersion: 'existing-version',
      ),
    );
    expect(
      (await state.readPendingConflict())?.remoteLineage.backupId,
      'existing-conflict',
    );

    // Reconnecting the same stable account keeps its verified cursor and
    // conflict, which will be revalidated before conflict resolution.
    await state.setCloudSyncEnabled(true);
    expect(
      await state.readCursor(),
      const CloudSyncCursor(
        lastSyncedLocalRevision: 7,
        lastSyncedBackupId: 'existing-backup',
        lastSyncedRemoteVersion: 'existing-version',
      ),
    );
    expect(
      (await state.readPendingConflict())?.remoteLineage.backupId,
      'existing-conflict',
    );
  });

  test('reconnect-required cannot be set when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');

    await state.setReconnectRequired(true);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isReconnectRequired(), isFalse);
  });

  test('automatic sync cannot be enabled when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');

    await expectLater(
      state.setAutomaticSyncEnabled(true),
      throwsA(isA<CloudAdapterException>()),
    );
  });

  test('explicit OFF is distinguishable from an unset preference', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');

    expect(await state.hasAutomaticSyncPreference(), isFalse);
    await state.setCloudSyncEnabled(true);
    await state.setAutomaticSyncEnabled(false);

    final restored = SharedPreferencesCloudSyncStateStore();
    expect(await restored.hasAutomaticSyncPreference(), isTrue);
    expect(await restored.isAutomaticSyncEnabled(), isFalse);
  });

  test('backup frequency persists across state-store recreation', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setBackupFrequency(CloudBackupFrequency.monthly);

    expect(
      await SharedPreferencesCloudSyncStateStore().backupFrequency(),
      CloudBackupFrequency.monthly,
    );
  });

  test('reconnect-required flag survives state-store recreation', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');

    await state.setCloudSyncEnabled(true);
    await state.setReconnectRequired(true);

    expect(
      await SharedPreferencesCloudSyncStateStore().isReconnectRequired(),
      isTrue,
    );
  });

  test('last successful timestamp round-trips in UTC', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    await state.setActiveAccountId('google-account-A');
    final value = DateTime.utc(2026, 10, 9, 7, 30);

    await state.setLastSuccessfulSyncAt(value);

    expect(await state.lastSuccessfulSyncAt(), value);
  });

  test(
    'pending conflicts survive state-store recreation and can be cleared',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
      await state.setActiveAccountId('google-account-A');
      final conflict = CloudConflict(
        localDeviceId: 'device-local',
        localTimestamp: DateTime.utc(2026, 10, 9, 7),
        localRevision: 12,
        localBaseBackupId: 'backup-10',
        remoteLineage: CloudLineage(
          deviceId: 'device-remote',
          backupId: 'backup-12',
          baseBackupId: 'backup-10',
          dbRevision: 11,
          createdAt: DateTime.utc(2026, 10, 9, 6),
        ),
        remoteTimestamp: DateTime.utc(2026, 10, 9, 6),
        remoteVersion: 'version-12',
        lastSyncedBackupId: 'backup-10',
      );

      await state.writePendingConflict(conflict);

      final restored = await SharedPreferencesCloudSyncStateStore()
          .readPendingConflict();
      expect(restored!.toDisplayData(), conflict.toDisplayData());

      await state.clearPendingConflict();
      expect(await state.readPendingConflict(), isNull);
    },
  );
  test(
    'sync cursor, conflict, timestamp and reconnect flag are isolated A-B-A',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
      final accountAConflict = _conflict('backup-A');
      final accountBConflict = _conflict('backup-B');
      final timestampA = DateTime.utc(2026, 10, 10, 8);
      final timestampB = DateTime.utc(2026, 10, 11, 9);

      await state.setActiveAccountId('google-account-A');
      await state.setCloudSyncEnabled(true);
      await state.writeCursor(
        const CloudSyncCursor(
          lastSyncedLocalRevision: 5,
          lastSyncedBackupId: 'backup-A',
          lastSyncedRemoteVersion: 'version-A',
        ),
      );
      await state.writePendingConflict(accountAConflict);
      await state.setLastSuccessfulSyncAt(timestampA);
      await state.setReconnectRequired(true);
      await state.setAutomaticSyncEnabled(true);
      await state.setBackupFrequency(CloudBackupFrequency.weekly);

      await state.setActiveAccountId('google-account-B');
      expect(await state.isCloudSyncEnabled(), isFalse);
      expect(await state.readCursor(), const CloudSyncCursor.empty());
      expect(await state.readPendingConflict(), isNull);
      expect(await state.lastSuccessfulSyncAt(), isNull);
      expect(await state.isReconnectRequired(), isFalse);

      await state.setCloudSyncEnabled(true);
      await state.writeCursor(
        const CloudSyncCursor(
          lastSyncedLocalRevision: 8,
          lastSyncedBackupId: 'backup-B',
          lastSyncedRemoteVersion: 'version-B',
        ),
      );
      await state.writePendingConflict(accountBConflict);
      await state.setLastSuccessfulSyncAt(timestampB);

      await state.setActiveAccountId('google-account-A');
      expect(await state.isCloudSyncEnabled(), isTrue);
      expect(
        await state.readCursor(),
        const CloudSyncCursor(
          lastSyncedLocalRevision: 5,
          lastSyncedBackupId: 'backup-A',
          lastSyncedRemoteVersion: 'version-A',
        ),
      );
      expect(
        (await state.readPendingConflict())?.remoteLineage.backupId,
        'backup-A',
      );
      expect(await state.lastSuccessfulSyncAt(), timestampA);
      expect(await state.isReconnectRequired(), isTrue);

      await state.setActiveAccountId('google-account-B');
      expect(await state.isCloudSyncEnabled(), isTrue);
      expect(
        await state.readCursor(),
        const CloudSyncCursor(
          lastSyncedLocalRevision: 8,
          lastSyncedBackupId: 'backup-B',
          lastSyncedRemoteVersion: 'version-B',
        ),
      );
      expect(
        (await state.readPendingConflict())?.remoteLineage.backupId,
        'backup-B',
      );
      expect(await state.lastSuccessfulSyncAt(), timestampB);

      // Cadence is a user preference, not account sync state.
      expect(await state.isAutomaticSyncEnabled(), isTrue);
      expect(await state.backupFrequency(), CloudBackupFrequency.weekly);
    },
  );

  test(
    'ambiguous legacy state is quarantined instead of assigned to account',
    () async {
      const legacyCursor =
          '{"last_synced_local_revision":4,"last_synced_backup_id":"legacy-backup","last_synced_remote_version":"legacy-version"}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'qaza_cloud_adapter.cached_account_email_v1': 'old@example.com',
        'qaza_cloud_adapter.cloud_enabled_v1': true,
        'qaza_cloud_adapter.sync_cursor_v1': legacyCursor,
        'qaza_cloud_adapter.last_successful_sync_at_v1':
            '2026-10-09T07:30:00.000Z',
        'qaza_cloud_adapter.automatic_sync_enabled_v1': true,
        'qaza_cloud_adapter.backup_frequency_v1': 'weekly',
      });
      final preferences = await SharedPreferences.getInstance();
      final state = SharedPreferencesCloudSyncStateStore(
        preferences: preferences,
      );

      expect(await state.hasUnscopedLegacyConnection(), isTrue);
      await state.setActiveAccountId('new-account-B');

      expect(await state.isCloudSyncEnabled(), isFalse);
      expect(await state.readCursor(), const CloudSyncCursor.empty());
      expect(await state.lastSuccessfulSyncAt(), isNull);
      expect(
        preferences.getString(
          'qaza_cloud_adapter.legacy_quarantine_v1.sync_cursor_v1',
        ),
        legacyCursor,
      );
      expect(
        preferences.containsKey('qaza_cloud_adapter.sync_cursor_v1'),
        isFalse,
      );
      expect(await state.isAutomaticSyncEnabled(), isTrue);
      expect(await state.backupFrequency(), CloudBackupFrequency.weekly);
    },
  );
  test(
    'in-flight account state stays pinned after active account switches',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
      await state.setActiveAccountId('google-account-A');
      await state.setCloudSyncEnabled(true);
      final operationState = state.scopedToAccount('google-account-A');

      await state.setActiveAccountId('google-account-B');
      expect(await state.readCursor(), const CloudSyncCursor.empty());

      await operationState.writeCursor(
        const CloudSyncCursor(
          lastSyncedLocalRevision: 6,
          lastSyncedBackupId: 'backup-from-A',
          lastSyncedRemoteVersion: 'version-from-A',
        ),
      );
      await operationState.setLastSuccessfulSyncAt(
        DateTime.utc(2026, 10, 12, 9),
      );

      expect(await state.readCursor(), const CloudSyncCursor.empty());
      expect(await state.lastSuccessfulSyncAt(), isNull);

      await state.setActiveAccountId('google-account-A');
      expect(
        await state.readCursor(),
        const CloudSyncCursor(
          lastSyncedLocalRevision: 6,
          lastSyncedBackupId: 'backup-from-A',
          lastSyncedRemoteVersion: 'version-from-A',
        ),
      );
      expect(await state.lastSuccessfulSyncAt(), DateTime.utc(2026, 10, 12, 9));
    },
  );

  test('cursor writes require a selected account namespace', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await expectLater(
      state.writeCursor(
        const CloudSyncCursor(
          lastSyncedLocalRevision: 2,
          lastSyncedBackupId: 'backup',
          lastSyncedRemoteVersion: 'version',
        ),
      ),
      throwsA(isA<CloudAdapterException>()),
    );
  });
  test(
    'disconnect quarantines ambiguous legacy state and stops cloud work',
    () async {
      const legacyCursor =
          '{"last_synced_local_revision":3,"last_synced_backup_id":"legacy","last_synced_remote_version":"v3"}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'qaza_cloud_adapter.cloud_enabled_v1': true,
        'qaza_cloud_adapter.sync_cursor_v1': legacyCursor,
        'qaza_cloud_adapter.automatic_sync_enabled_v1': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final state = SharedPreferencesCloudSyncStateStore(
        preferences: preferences,
      );

      expect(await state.hasUnscopedLegacyConnection(), isTrue);
      await state.setCloudSyncEnabled(false);

      expect(await state.isCloudSyncEnabled(), isFalse);
      expect(await state.hasUnscopedLegacyConnection(), isFalse);
      expect(
        preferences.getString(
          'qaza_cloud_adapter.legacy_quarantine_v1.sync_cursor_v1',
        ),
        legacyCursor,
      );
      expect(await state.isAutomaticSyncEnabled(), isTrue);
    },
  );
}

CloudConflict _conflict(String backupId) => CloudConflict(
  localDeviceId: 'device-local-$backupId',
  localTimestamp: DateTime.utc(2026, 10, 10),
  localRevision: 12,
  localBaseBackupId: 'base-$backupId',
  remoteLineage: CloudLineage(
    deviceId: 'device-remote-$backupId',
    backupId: backupId,
    baseBackupId: 'base-$backupId',
    dbRevision: 11,
    createdAt: DateTime.utc(2026, 10, 9, 6),
  ),
  remoteTimestamp: DateTime.utc(2026, 10, 9, 6),
  remoteVersion: 'version-$backupId',
  lastSyncedBackupId: 'base-$backupId',
);
