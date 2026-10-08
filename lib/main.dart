import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'app/app.dart';
import 'core/widgets/fatal_error_screen.dart';
import 'core/diagnostics/diagnostics.dart';
import 'core/time/local_date_service.dart';
import 'data/local/database/app_database.dart';

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
            runApp(const ProviderScope(child: QazaNamazApp()));
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

  runApp(const ProviderScope(child: QazaNamazApp()));
}

Future<void> _initializeDatabase() async {
  final database = AppDatabase();
  try {
    // Force the encrypted Drift database to open and validate its schema.
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
      name == 'database'
          ? DiagnosticArea.databaseMigration
          : DiagnosticArea.startup,
      '${name}_failed',
      error,
      stack: stack,
    );
  }
}
