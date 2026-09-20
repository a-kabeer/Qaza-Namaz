import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'data/local/database/app_database.dart';
import 'data/migration/qaza_database_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check must be activated immediately after Firebase initialization and
  // before any Firebase service is used. Debug builds use the Firebase debug
  // provider; Android release builds use Play Integrity.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  // Complete the legacy migration before any repository can read the local
  // database. The legacy SharedPreferences document remains untouched.
  final database = AppDatabase();
  final preferences = await SharedPreferences.getInstance();
  await bootstrapQazaDatabase(
    database: database,
    preferences: preferences,
  );
  await database.close();

  runApp(const ProviderScope(child: QazaNamazApp()));
}
