import 'package:drift/drift.dart';

import 'app_database.dart';

/// Owns foreground database handles and is the only production entry point
/// allowed to construct database instances.
///
/// Phase 1 preserves the existing shared layout. The registry resolver is
/// intentionally fail-closed for separate layouts until Phase 2 implements
/// verified per-Google-file opening.
class DatabaseManager {
  DatabaseManager({AppDatabase? controlDatabase})
      : _controlDatabase = controlDatabase;

  AppDatabase? _controlDatabase;
  final Map<String, AppDatabase> _workspaceDatabases = <String, AppDatabase>{};

  /// The control + Guest database. Opening is lazy through Drift's executor.
  AppDatabase get controlDatabase =>
      _controlDatabase ??= AppDatabase.control();

  /// Resolves a workspace using the authoritative control registry.
  ///
  /// During Phase 1 every registered workspace remains in the shared file. A
  /// future separate-layout row must never silently fall back to this handle.
  Future<AppDatabase> databaseForWorkspace(String localAccountId) async {
    final id = localAccountId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    final rows = await controlDatabase.customSelect(
      'SELECT db_layout, db_file_name FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: <Variable<Object>>[Variable<String>(id)],
    ).get();
    if (rows.isEmpty) {
      throw StateError('The requested local workspace is not registered.');
    }
    final layout = rows.single.read<String>('db_layout');
    if (layout == 'shared') return controlDatabase;
    if (layout == 'separate') {
      throw StateError(
        'This workspace is registered in a separate database, but verified '
        'separate-file routing is not yet available.',
      );
    }
    throw StateError('The workspace database layout is invalid.');
  }

  /// Closes each owned handle exactly once.
  Future<void> close() async {
    final handles = <AppDatabase>{
      if (_controlDatabase != null) _controlDatabase!,
      ..._workspaceDatabases.values,
    };
    _controlDatabase = null;
    _workspaceDatabases.clear();
    for (final database in handles) {
      await database.close();
    }
  }
}
