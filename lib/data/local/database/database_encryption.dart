import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Owns the single database-encryption key for the app-local ledger.
///
/// The key itself never lives in the SQLite file, SharedPreferences, logs, or
/// exported application data. On Android, flutter_secure_storage stores it
/// using its platform-secured encrypted storage backed by Android keystore
/// primitives.
class DatabaseEncryptionKeyStore {
  DatabaseEncryptionKeyStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String keyName = 'qaza_namaz_database_key_v1';
  static const int keyBytes = 32;

  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: keyName);
    if (existing != null) {
      _validateEncodedKey(existing);
      return existing;
    }

    final bytes = List<int>.generate(
      keyBytes,
      (_) => Random.secure().nextInt(256),
      growable: false,
    );
    final encoded = base64UrlEncode(bytes);
    await _storage.write(key: keyName, value: encoded);
    return encoded;
  }

  void _validateEncodedKey(String value) {
    try {
      final bytes = base64Url.decode(value);
      if (bytes.length != keyBytes) {
        throw const FormatException();
      }
    } on FormatException {
      throw StateError(
        'The local database encryption key is invalid or corrupted.',
      );
    }
  }
}

/// Migrates the legacy plaintext Drift database to encrypted SQLite before
/// Drift gets access to the file.
///
/// The original file is kept intact until the encrypted copy has been fully
/// verified. An interrupted swap is recovered on the next startup.
class PlaintextDatabaseMigrator {
  static const List<int> _sqliteHeader = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  static Future<void> migrateIfNeeded({
    required File databaseFile,
    required String key,
  }) async {
    final database = databaseFile;
    final temporary = File('${database.path}.encryption-migration.tmp');
    final backup = File('${database.path}.encryption-migration.backup');

    if (!await database.exists() && await backup.exists()) {
      await backup.rename(database.path);
    }

    if (!await database.exists()) {
      return;
    }

    final header = await _readHeader(database);
    if (!_isPlaintextSqlite(header)) {
      if (await backup.exists()) {
        await backup.delete();
      }
      return;
    }

    if (await temporary.exists()) {
      await temporary.delete();
    }

    final escapedTemporaryPath = _escapeSqlString(temporary.path);
    final escapedKey = _escapeSqlString(key);

    final plaintext = sqlite3.sqlite3.open(database.path);
    try {
      plaintext.execute("VACUUM INTO '$escapedTemporaryPath';");
    } finally {
      plaintext.close();
    }

    final encryptedCopy = sqlite3.sqlite3.open(temporary.path);
    try {
      encryptedCopy.execute("PRAGMA rekey = '$escapedKey';");
    } finally {
      encryptedCopy.close();
    }

    _verifyEncryptedDatabase(temporary, key);

    if (await backup.exists()) {
      await backup.delete();
    }

    await database.rename(backup.path);
    try {
      await temporary.rename(database.path);
    } catch (_) {
      if (!await database.exists() && await backup.exists()) {
        await backup.rename(database.path);
      }
      rethrow;
    }

    await backup.delete();
  }

  static Future<List<int>> _readHeader(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(16);
    } finally {
      await raf.close();
    }
  }

  static bool _isPlaintextSqlite(List<int> header) {
    if (header.length < _sqliteHeader.length) return false;
    for (var i = 0; i < _sqliteHeader.length; i++) {
      if (header[i] != _sqliteHeader[i]) return false;
    }
    return true;
  }

  static void _verifyEncryptedDatabase(File file, String key) {
    final escapedKey = _escapeSqlString(key);
    final database = sqlite3.sqlite3.open(file.path);
    try {
      final cipher = database.select('PRAGMA cipher;');
      if (cipher.isEmpty) {
        throw StateError(
          'Encrypted SQLite support is unavailable in this build.',
        );
      }

      database.execute("PRAGMA key = '$escapedKey';");
      database.select('SELECT count(*) FROM sqlite_master;');
    } finally {
      database.close();
    }
  }

  static String _escapeSqlString(String value) => value.replaceAll("'", "''");
}
