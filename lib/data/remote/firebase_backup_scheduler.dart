import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../local/account_local_store.dart';
import '../local/database/app_database.dart';
import 'firebase_backup_service.dart';
import 'firebase_backup_worker.dart';
import 'firebase_services.dart';

class FirebaseBackupScheduler {
  static const String uniqueWorkName = 'qaza_namaz_backup_periodic';
  static const String taskName = 'qaza_namaz_backup';
  static const Duration frequency = Duration(minutes: 15);

  static Future<void>? _initialization;

  static Future<void> initialize() {
    final running = _initialization;
    if (running != null) return running;

    final future = _initializeInternal();
    _initialization = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_initialization, future)) {
          _initialization = null;
        }
      }),
    );
    return future;
  }

  static Future<void> _initializeInternal() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final workmanager = Workmanager();
    await workmanager.initialize(firebaseBackupTaskDispatcher);
    await workmanager.registerPeriodicTask(
      uniqueWorkName,
      taskName,
      frequency: frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: 'qaza_namaz_backup',
    );
  }
}

@pragma('vm:entry-point')
void firebaseBackupTaskDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != FirebaseBackupScheduler.taskName) return true;

    final database = AppDatabase();
    final diagnostics = PersistentDiagnostics(
      capacity: 100,
      storageKey: 'qaza_backup_diagnostic_events',
    );

    try {
      final accountStore = AccountLocalStore(database: database);
      final firebase = FirebaseServices(diagnostics: diagnostics);
      final auth = GoogleFirebaseAuthService(firebase);
      final backup = FirebaseBackupService(
        firebase: firebase,
        database: database,
        accountStore: accountStore,
      );
      final worker = FirebaseBackupWorker(
        firebase: firebase,
        accountStore: accountStore,
        backupService: backup,
        authService: auth,
      );

      await worker.runOnce();
      return true;
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.sync,
        'background_backup_task_failed',
        error,
        stack: stack,
      );
      return false;
    } finally {
      await database.close();
    }
  });
}
