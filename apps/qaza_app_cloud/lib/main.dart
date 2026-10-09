import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:qaza_namaz/app/app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';
import 'package:qaza_namaz/core/widgets/fatal_error_screen.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

const Duration _startupStepTimeout = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  const diagnostics = DebugDiagnostics();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    diagnostics.recordFailure(
      DiagnosticArea.uncaught,
      'flutter_error',
      details.exception,
      stack: details.stack,
      fatal: true,
    );
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.uncaught,
      'platform_error',
      error,
      stack: stack,
      fatal: true,
    );
    return false;
  };

  await _step('timezone', () async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    LocalDateService.configureLocalTimezone(timezone.identifier);
  });

  const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  final gateway = GoogleSignInGateway(
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );
  final state = SharedPreferencesCloudSyncStateStore();
  final scheduler = CloudSyncScheduler(state: state);

  try {
    await _initializeDatabase();
  } catch (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.databaseMigration,
      'database_initialization_failed',
      error,
      stack: stack,
      fatal: true,
    );
    runApp(
      FatalDatabaseErrorApp(
        error: error,
        onRetry: () async {
          try {
            await _initializeDatabase();
            runApp(_cloudApp(gateway, state, scheduler, serverClientId));
          } catch (retryError, retryStack) {
            diagnostics.recordFailure(
              DiagnosticArea.databaseMigration,
              'database_retry_failed',
              retryError,
              stack: retryStack,
              fatal: true,
            );
            Error.throwWithStackTrace(retryError, retryStack);
          }
        },
      ),
    );
    return;
  }

  runApp(_cloudApp(gateway, state, scheduler, serverClientId));
}

Widget _cloudApp(
  GoogleSignInGateway gateway,
  SharedPreferencesCloudSyncStateStore state,
  CloudSyncScheduler scheduler,
  String serverClientId,
) {
  return ProviderScope(
    overrides: [
      packageAssetNamespaceProvider.overrideWithValue('qaza_namaz'),
      cloudAccountProvider.overrideWith(
        (ref) => GoogleCloudAccountProvider(
          gateway: gateway,
          state: state,
          scheduler: scheduler,
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        ),
      ),
      cloudSyncProvider.overrideWith(
        (ref) => GoogleCloudSyncProvider(
          database: ref.watch(appDatabaseProvider),
          gateway: gateway,
          state: state,
          scheduler: scheduler,
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        ),
      ),
    ],
    child: const QazaNamazApp(),
  );
}

Future<void> _initializeDatabase() async {
  final database = AppDatabase();
  try {
    await database.readDbRevision();
  } finally {
    await database.close();
  }
}

Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body().timeout(_startupStepTimeout);
  } catch (error, stack) {
    const DebugDiagnostics().recordFailure(
      DiagnosticArea.startup,
      '${name}_failed',
      error,
      stack: stack,
    );
  }
}
