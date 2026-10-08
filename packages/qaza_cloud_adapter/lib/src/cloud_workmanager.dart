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

Duration normalizeCloudSyncFrequency(Duration requested) {
  const minimum = Duration(minutes: 15);
  return requested < minimum ? minimum : requested;
}

void initializeQazaCloudBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != cloudSyncWorkerTaskName) {
      return true;
    }

    final serverClientId = inputData?['server_client_id'] as String?;
    final appDatabase = AppDatabase();
    final phase1 = LocalPhase1BackupSource(appDatabase);

    try {
      final gateway = GoogleSignInGateway(serverClientId: serverClientId);
      final remote = GoogleDriveAppDataStore(gateway);
      final state = SharedPreferencesCloudSyncStateStore();
      final engine = CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: state,
      );
      final result = await engine.sync(allowInteractive: false);

      return result.isSuccessful;
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
  CloudSyncScheduler({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;
  bool _initialized = false;

  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {
    if (!_initialized) {
      await _workmanager.initialize(initializeQazaCloudBackgroundDispatcher);
      _initialized = true;
    }

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
  }

  Future<void> cancel() =>
      _workmanager.cancelByUniqueName(cloudSyncWorkerTaskName);
}
