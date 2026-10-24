import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:qaza_namaz/app/app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/core/licenses/app_license_registry.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';
import 'package:qaza_namaz/core/widgets/fatal_error_screen.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';

import 'google_sign_in_identity_provider.dart';

const Duration _startupStepTimeout = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicenses();
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
  final identity = GoogleSignInIdentityProvider(
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );

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
            runApp(_identityApp(identity));
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

  runApp(_identityApp(identity));
}

Widget _identityApp(GoogleSignInIdentityProvider identity) {
  return ProviderScope(
    overrides: [
      googleIdentityProvider.overrideWithValue(identity),
      packageAssetNamespaceProvider.overrideWithValue('qaza_namaz'),
    ],
    child: const QazaNamazApp(),
  );
}

Future<void> _initializeDatabase() async {
  final databaseManager = DatabaseManager();
  try {
    await databaseManager.initialize();
    await databaseManager.runStartupMigrations();
  } finally {
    await databaseManager.close();
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
