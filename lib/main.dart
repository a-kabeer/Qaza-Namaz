import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/diagnostics/diagnostics.dart';
import 'data/local/database/app_database.dart';
import 'data/migration/qaza_database_bootstrap.dart';
import 'firebase_options.dart';

/// How long any single startup step may take before the app gives up on it.
///
/// Nothing here is worth a launch for. The app is offline-first: it opens,
/// and whatever did not finish is retried or simply unavailable.
const Duration _startupStepTimeout = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash-rate monitoring: both of the places Flutter surfaces an otherwise
  // unhandled error. Reported through the same port as everything else, so a
  // backend picks these up the moment one is wired in.
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

  // Every step below is optional to *starting*. A failure or a stall in any
  // of them used to mean `runApp` was never reached, which the user sees as a
  // launch that hangs or a black screen with nothing to act on.
  await _step('firebase', () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check is activated immediately after Firebase initialization and
    // before any Firebase service is used. The enum-style provider API is
    // used here because the app remains on the Firebase Core 3.x line.
    // Debug builds use the Firebase debug provider; release builds use Play
    // Integrity, which is the one startup step that behaves differently in a
    // release build and so the one most likely to stall in one.
    final appCheckProvider =
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity;

    await FirebaseAppCheck.instance.activate(
      androidProvider: appCheckProvider,
    );
    diagnostics.recordEvent(
      DiagnosticArea.startup,
      'app_check_activated_${kDebugMode ? 'debug' : 'play_integrity'}',
    );

    // The debug provider can fail independently of Firebase initialization.
    // Probe token acquisition in debug builds so a missing/invalid debug token
    // is distinguishable from an OAuth or Firebase Auth failure. Never log the
    // token itself.
    if (kDebugMode) {
      try {
        final token = await FirebaseAppCheck.instance
            .getToken()
            .timeout(const Duration(seconds: 3));
        if (token == null || token.isEmpty) {
          throw StateError('Firebase App Check returned no debug token.');
        }
        diagnostics.recordEvent(
          DiagnosticArea.startup,
          'app_check_debug_token_ready',
        );
      } catch (error, stack) {
        diagnostics.recordFailure(
          DiagnosticArea.startup,
          'app_check_debug_token_failed',
          error,
          stack: stack,
        );
      }
    }
  });

  // Complete the legacy migration before any repository can read the local
  // database. The legacy SharedPreferences document remains untouched.
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

  runApp(const ProviderScope(child: QazaNamazApp()));
}

/// Runs one startup step, bounded and non-fatal.
Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body().timeout(_startupStepTimeout);
  } catch (error, stack) {
    // Startup steps are non-fatal by design, which is exactly why they need
    // reporting: a silent failure here is invisible in the field.
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
