import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_models.dart';
import 'cloud_state_store.dart';
import 'google_drive_store.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';
import 'sync_engine.dart';

const String cloudSyncWorkerTaskName = 'qaza_namaz_cloud_periodic_sync';
const String _scheduledFrequencyDaysKey =
    'qaza_cloud_adapter.scheduled_frequency_days_v1';

/// WorkManager may defer a run because of constraints, battery policy, or
/// other system limits. Unsupported custom intervals safely fall back to Daily.
Duration normalizeCloudSyncFrequency(Duration requested) {
  const daily = Duration(days: 1);
  const weekly = Duration(days: 7);
  const monthly = Duration(days: 30);
  if (requested == daily || requested == weekly || requested == monthly) {
    return requested;
  }
  return daily;
}

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

      // A missing token/account in a background isolate must never trigger an
      // account picker. Persist a reconnect hint without disabling cloud sync
      // or erasing the user's daily-backup preference.
      if (result.kind == CloudSyncResultKind.skipped &&
          (result.message?.toLowerCase().contains('authorization') ?? false)) {
        await state.setReconnectRequired(true);
      } else if (result.kind != CloudSyncResultKind.skipped &&
          result.kind != CloudSyncResultKind.failed &&
          result.kind != CloudSyncResultKind.remoteMissing) {
        await state.setReconnectRequired(false);
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

      // Avoid resetting the next run every time the Account screen restores
      // status. Re-register only for a new schedule, or a cadence change.
      final normalized = normalizeCloudSyncFrequency(frequency);
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getInt(_scheduledFrequencyDaysKey) ==
          normalized.inDays) {
        return;
      }
      final inputData = <String, dynamic>{
        if (serverClientId != null) 'server_client_id': serverClientId,
      };

      await _workmanager.registerPeriodicTask(
        cloudSyncWorkerTaskName,
        cloudSyncWorkerTaskName,
        frequency: normalized,
        inputData: inputData,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      await preferences.setInt(_scheduledFrequencyDaysKey, normalized.inDays);
    } catch (_) {
      // Keep the user's intended preference intact if scheduling fails. The
      // caller receives the registration error and can surface it in the UI.
      rethrow;
    }
  }

  Future<void> _cancelScheduledWork() async {
    try {
      await _workmanager.cancelByUniqueName(cloudSyncWorkerTaskName);
    } finally {
      // A subsequent re-enable must register work even if cancellation throws.
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_scheduledFrequencyDaysKey);
    }
  }

  Future<void> cancel() async {
    // Persist the disabled state before cancelling unique periodic work.
    await _state.setAutomaticSyncEnabled(false);
    await _cancelScheduledWork();
  }

  Future<void> disconnect() async {
    // The hard stop is durable before cancellation or account sign-out.
    await _state.setCloudSyncEnabled(false);
    // The cloud flag hard-stops workers; preserve the user's saved preference
    // so reconnecting does not silently change their choice.
    await _cancelScheduledWork();
  }
}
