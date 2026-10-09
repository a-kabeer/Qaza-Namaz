import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_models.dart';
import 'cloud_state_store.dart';
import 'google_drive_store.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';
import 'sync_engine.dart';

const String cloudSyncWorkerTaskName = 'qaza_namaz_cloud_periodic_sync';

/// Product policy fixes automatic backup to daily regardless of caller input.
/// Android may defer the interval; it is not an exact 24-hour deadline.
Duration normalizeCloudSyncFrequency(Duration requested) =>
    requested == const Duration(days: 1)
        ? requested
        : const Duration(days: 1);

@pragma('vm:entry-point')
void initializeQazaCloudBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != cloudSyncWorkerTaskName) {
      return true;
    }

    final serverClientId = inputData?['server_client_id'] as String?;
    final state = SharedPreferencesCloudSyncStateStore();

    // Must run before AppDatabase opening, Google authorization or network work.
    if (!await state.isCloudSyncEnabled() ||
        !await state.isAutomaticSyncEnabled()) {
      return true;
    }

    final appDatabase = AppDatabase();
    final phase1 = LocalPhase1BackupSource(appDatabase);

    try {
      final gateway = GoogleSignInGateway(serverClientId: serverClientId);
      final remote = GoogleDriveAppDataStore(gateway);
      final engine = CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      );
      final result = await engine.sync(allowInteractive: false);
      if (result.kind == CloudSyncResultKind.uploaded ||
          result.kind == CloudSyncResultKind.downloaded) {
        await state.setLastSuccessfulSyncAt(DateTime.now().toUtc());
      }

      // A conflict needs a user choice, not an automatic WorkManager retry.
      return result.kind != CloudSyncResultKind.failed &&
          result.kind != CloudSyncResultKind.remoteMissing;
    } on CloudAdapterException {
      return true;
    } catch (_) {
      return false;
    } finally {
      await appDatabase.close();
    }
  });
}

class CloudSyncScheduler {
  CloudSyncScheduler({Workmanager? workmanager, CloudSyncStateStore? state})
    : _workmanager = workmanager ?? Workmanager(),
      _state = state ?? SharedPreferencesCloudSyncStateStore();

  final Workmanager _workmanager;
  final CloudSyncStateStore _state;
  bool _initialized = false;

  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {
    if (!await _state.isCloudSyncEnabled()) {
      throw const CloudAdapterException(
        'Connect a Google account before scheduling automatic backup.',
      );
    }
    await _state.setAutomaticSyncEnabled(true);
    try {
      if (!_initialized) {
        await _workmanager.initialize(initializeQazaCloudBackgroundDispatcher);
        _initialized = true;
      }

      // Keep the cadence daily even if a caller supplies a shorter interval.
      final normalized = normalizeCloudSyncFrequency(frequency);
      final inputData = <String, dynamic>{
        if (serverClientId != null) 'server_client_id': serverClientId,
      };

      await _workmanager.registerPeriodicTask(
        cloudSyncWorkerTaskName,
        cloudSyncWorkerTaskName,
        frequency: normalized,
        inputData: inputData,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // A failed registration must not leave the UI claiming automatic backup
      // is active when no periodic task could be registered.
      await _state.setAutomaticSyncEnabled(false);
      rethrow;
    }
  }

  Future<void> cancel() async {
    // Persist the disabled state before cancelling unique periodic work.
    await _state.setAutomaticSyncEnabled(false);
    await _workmanager.cancelByUniqueName(cloudSyncWorkerTaskName);
  }

  Future<void> disconnect() async {
    // The hard stop is durable before cancellation or account sign-out.
    await _state.setCloudSyncEnabled(false);
    await _state.setAutomaticSyncEnabled(false);
    await _workmanager.cancelByUniqueName(cloudSyncWorkerTaskName);
  }
}
