import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatic cloud backup cadence is fixed to daily', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(minutes: 5)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(hours: 1)),
      const Duration(days: 1),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cloud and automatic sync default to disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isFalse);
    expect(await state.lastSuccessfulSyncAt(), isNull);
  });

  test('disabling cloud durably disables automatic sync', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await state.setCloudSyncEnabled(true);
    await state.setAutomaticSyncEnabled(true);
    expect(await state.isAutomaticSyncEnabled(), isTrue);

    await state.setCloudSyncEnabled(false);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isFalse);
  });

  test('automatic sync cannot be enabled when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await expectLater(
      state.setAutomaticSyncEnabled(true),
      throwsA(isA<CloudAdapterException>()),
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
