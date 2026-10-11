import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatic backup cadence supports all selectable frequencies', () {
    expect(normalizeCloudSyncFrequency(const Duration(days: 1)),
        const Duration(days: 1));
    expect(normalizeCloudSyncFrequency(const Duration(days: 7)),
        const Duration(days: 7));
    expect(normalizeCloudSyncFrequency(const Duration(days: 30)),
        const Duration(days: 30));
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

    await state.setCloudSyncEnabled(true);
    await state.setAutomaticSyncEnabled(true);
    await state.setReconnectRequired(true);
    expect(await state.isAutomaticSyncEnabled(), isTrue);
    expect(await state.isReconnectRequired(), isTrue);

    await state.setCloudSyncEnabled(false);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isTrue);
    expect(await state.isReconnectRequired(), isFalse);
  });

  test('reconnect-required cannot be set when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await state.setReconnectRequired(true);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isReconnectRequired(), isFalse);
  });

  test('automatic sync cannot be enabled when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await expectLater(
      state.setAutomaticSyncEnabled(true),
      throwsA(isA<CloudAdapterException>()),
    );
  });

  test('explicit OFF is distinguishable from an unset preference', () async {
    final state = SharedPreferencesCloudSyncStateStore();

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

    await state.setCloudSyncEnabled(true);
    await state.setReconnectRequired(true);

    expect(
      await SharedPreferencesCloudSyncStateStore().isReconnectRequired(),
      isTrue,
    );
  });

  test('last successful timestamp round-trips in UTC', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    final value = DateTime.utc(2026, 10, 9, 7, 30);

    await state.setLastSuccessfulSyncAt(value);

    expect(await state.lastSuccessfulSyncAt(), value);
  });

  test(
    'pending conflicts survive state-store recreation and can be cleared',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
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
}
