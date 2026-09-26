import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/diagnostics/diagnostics.dart';
import 'data/local/database/app_database.dart';
import 'data/migration/qaza_database_bootstrap.dart';
import 'data/migration/user_profile_migration.dart';

const Duration _startupStepTimeout = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await _step('database', () async {
    final database = AppDatabase();
    try {
      await bootstrapQazaDatabase(
        database: database,
        preferences: await SharedPreferences.getInstance(),
      );
    } finally {
      await database.close();
    }
  });

  await _step('profile_migration', () async {
    await const UserProfileMigration().migrateLegacyProfileData(
      preferences: await SharedPreferences.getInstance(),
    );
  });

  runApp(const ProviderScope(child: QazaNamazApp()));
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
