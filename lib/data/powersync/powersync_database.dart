import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../local/database/database_encryption.dart';
import 'powersync_config.dart';
import 'powersync_schema.dart';
import 'supabase_connector.dart';

/// Provider for the single active PowerSync backend connector.
final powerSyncConnectorProvider = Provider<QazaSupabaseConnector>((ref) {
  return QazaSupabaseConnector();
});

/// Manages encrypted local PowerSync SQLite database instances per workspace.
class QazaPowerSyncDatabaseManager {
  QazaPowerSyncDatabaseManager._();

  static final Map<String, PowerSyncDatabase> _instances =
      <String, PowerSyncDatabase>{};
  static final Map<String, Future<PowerSyncDatabase>> _openingFutures =
      <String, Future<PowerSyncDatabase>>{};

  /// Returns the active or newly opened encrypted [PowerSyncDatabase] instance
  /// for the specified workspace or custom path.
  ///
  /// Guarantees that at most one [PowerSyncDatabase] instance exists per database file,
  /// preventing duplicate sync instances.
  static Future<PowerSyncDatabase> getInstance({
    String? workspaceId,
    String? customPath,
    String? encryptionKey,
    Schema? schema,
    DatabaseEncryptionKeyStore? keyStore,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final dbPath = customPath ??
        await resolveWorkspaceDatabasePath(
          workspaceId: workspaceId,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );

    // If an instance is already open and valid for this path, reuse it.
    final existing = _instances[dbPath];
    if (existing != null && !existing.database.closed) {
      return existing;
    }

    // If opening is currently in flight for this path, await the existing future.
    final inFlight = _openingFutures[dbPath];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _openEncryptedDatabase(
      dbPath: dbPath,
      workspaceId: workspaceId,
      encryptionKey: encryptionKey,
      schema: schema ?? qazaPowerSyncSchema,
      keyStore: keyStore ?? DatabaseEncryptionKeyStore(),
    );

    _openingFutures[dbPath] = future;
    try {
      final db = await future;
      _instances[dbPath] = db;
      return db;
    } finally {
      _openingFutures.remove(dbPath);
    }
  }

  static Future<PowerSyncDatabase> _openEncryptedDatabase({
    required String dbPath,
    required String? workspaceId,
    required String? encryptionKey,
    required Schema schema,
    required DatabaseEncryptionKeyStore keyStore,
  }) async {
    // Resolve encryption key:
    // 1. Explicit key if provided
    // 2. Workspace-specific key from secure storage if workspaceId provided
    // 3. Master default encryption key from secure storage
    final key = encryptionKey ??
        (workspaceId != null && workspaceId.trim().isNotEmpty
            ? await keyStore.readOrCreateForWorkspace(workspaceId)
            : await keyStore.readOrCreate());

    // Configure SQLCipher-compatible SQLite3MultipleCiphers encryption
    final encryptionOptions = EncryptionOptions(
      key: key,
      sqlcipherCompatibility: true,
    );

    final db = PowerSyncDatabase(
      schema: schema,
      path: dbPath,
      encryption: encryptionOptions,
    );

    await db.initialize();
    return db;
  }

  /// Resolves the filesystem path for a workspace's encrypted PowerSync database.
  ///
  /// - Guest: `qaza_powersync_guest.db`
  /// - Google: `qaza_powersync_google_<hash32>.db`
  /// - Default/Primary: `qaza_powersync_primary.db`
  static Future<String> resolveWorkspaceDatabasePath({
    String? workspaceId,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final appDir = documentsDirectoryProvider != null
        ? await documentsDirectoryProvider()
        : await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'qaza_powersync'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final id = workspaceId?.trim();
    if (id == null || id.isEmpty) {
      return p.join(dir.path, 'qaza_powersync_primary.db');
    }
    if (id == 'guest' || id.startsWith('guest_') || id.startsWith('guest:')) {
      return p.join(dir.path, 'qaza_powersync_guest.db');
    }

    // Google workspace or other authenticated identity: hash identifier to prevent PII exposure
    final stableId =
        id.startsWith('google_') ? id.substring('google_'.length) : id;
    final hash = sha256.convert(utf8.encode(stableId)).toString();
    final prefix = id.startsWith('google_')
        ? 'qaza_powersync_google_'
        : 'qaza_powersync_ws_';
    return p.join(dir.path, '$prefix${hash.substring(0, 32)}.db');
  }

  /// Connects PowerSync sync streams using the provided connector for the given workspace.
  ///
  /// Returns `true` if connected, or `false` if the workspace is not authorized for cloud sync (Phase 3B controlled gate).
  static Future<bool> connect(
    QazaSupabaseConnector connector, {
    String? workspaceId,
    String? customPath,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (!PowerSyncConfig.isWorkspaceAuthorizedForCloudSync(workspaceId)) {
      if (kDebugMode) {
        debugPrint(
          '[QazaPowerSyncDatabaseManager] Cloud sync not authorized for workspace "$workspaceId". '
          'Preserving local-only persistence engine (Phase 3B gate).',
        );
      }
      return false;
    }

    final db = await getInstance(
      workspaceId: workspaceId,
      customPath: customPath,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    await db.connect(connector: connector);
    return true;
  }

  /// Safely disconnects replication streams without destroying local records or pending CRUD transactions.
  static Future<void> disconnect({
    String? workspaceId,
    String? customPath,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (_instances.isEmpty) return;
    if (workspaceId == null && customPath == null) {
      for (final db in _instances.values) {
        if (!db.database.closed) {
          await db.disconnect();
        }
      }
      return;
    }

    final dbPath = customPath ??
        await resolveWorkspaceDatabasePath(
          workspaceId: workspaceId,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
    final db = _instances[dbPath];
    if (db != null && !db.database.closed) {
      await db.disconnect();
    }
  }

  /// Disconnects replication and optionally clears synced tables upon explicit account removal.
  static Future<void> disconnectAndClear({
    String? workspaceId,
    String? customPath,
    bool clearLocal = true,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (_instances.isEmpty) {
      return;
    }

    if (workspaceId == null && customPath == null) {
      // Disconnect and clear all active instances
      final dbs = List<PowerSyncDatabase>.from(_instances.values);
      _instances.clear();
      for (final db in dbs) {
        if (!db.database.closed) {
          await db.disconnectAndClear(clearLocal: clearLocal);
          await db.close();
        }
      }
      return;
    }

    final dbPath = customPath ??
        await resolveWorkspaceDatabasePath(
          workspaceId: workspaceId,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
    final db = _instances.remove(dbPath);
    if (db != null) {
      await db.disconnectAndClear(clearLocal: clearLocal);
      await db.close();
    }
  }

  /// Safely closes the database instance for a given workspace.
  static Future<void> closeDatabase({
    String? workspaceId,
    String? customPath,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (_instances.isEmpty) {
      return;
    }

    final dbPath = customPath ??
        await resolveWorkspaceDatabasePath(
          workspaceId: workspaceId,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
    final db = _instances.remove(dbPath);
    if (db != null && !db.database.closed) {
      try {
        await db.close();
      } catch (_) {}
    }
  }

  /// Closes all active PowerSync database instances.
  static Future<void> closeAll() async {
    final dbs = List<PowerSyncDatabase>.from(_instances.values);
    _instances.clear();
    _openingFutures.clear();
    for (final db in dbs) {
      if (!db.database.closed) {
        try {
          await db.close();
        } catch (_) {}
      }
    }
  }

  /// Creates a Drift database connection backed by PowerSync's SQLite database.
  ///
  /// Uses [SqliteAsyncDriftConnection] from package:drift_sqlite_async.
  static Future<QueryExecutor> createDriftConnection({
    String? workspaceId,
    String? customPath,
    String? encryptionKey,
    Schema? schema,
    DatabaseEncryptionKeyStore? keyStore,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final db = await getInstance(
      workspaceId: workspaceId,
      customPath: customPath,
      encryptionKey: encryptionKey,
      schema: schema,
      keyStore: keyStore,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    return SqliteAsyncDriftConnection(db);
  }
}
