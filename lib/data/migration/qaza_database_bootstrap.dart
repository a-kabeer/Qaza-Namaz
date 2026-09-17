import 'package:shared_preferences/shared_preferences.dart';

import '../local/database/app_database.dart';
import 'shared_preferences_to_drift_migrator.dart';

/// Runs the one-time legacy-to-Drift migration before repositories are created.
///
/// The migration is intentionally awaited during application bootstrap so the
/// first production repository cannot read a partially migrated database.
Future<MigrationResult> bootstrapQazaDatabase({
  required AppDatabase database,
  SharedPreferences? preferences,
}) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  return SharedPreferencesToDriftMigrator(
    database: database,
    preferences: prefs,
  ).migrate();
}
