import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

const _schema = Schema([
  Table('poc_records', [
    Column.text('label'),
  ]),
]);

String _keyWithSeed(int seed) =>
    base64UrlEncode(List<int>.generate(32, (i) => (i + seed) & 0xff));

PowerSyncDatabase _openDatabase({
  required String path,
  String? key,
}) {
  return PowerSyncDatabase(
    schema: _schema,
    path: path,
    // Match the app's current SQLite3MultipleCiphers configuration: PRAGMA key
    // with the existing Base64URL-encoded 32-byte key, not SQLCipher legacy mode.
    encryption: key == null
        ? null
        : EncryptionOptions(key: key, sqlcipherCompatibility: false),
  );
}

Future<List<int>> _readHeader(String path) async {
  final file = await File(path).open(mode: FileMode.read);
  try {
    return await file.read(16);
  } finally {
    await file.close();
  }
}

Future<Object?> _tryOpenAndRead({
  required String path,
  String? key,
}) async {
  PowerSyncDatabase? database;
  try {
    database = _openDatabase(path: path, key: key);
    await database.initialize();
    await database.get('SELECT label FROM poc_records LIMIT 1');
    return null;
  } catch (error) {
    return error;
  } finally {
    try {
      if (database != null && !database.closed) {
        await database.close();
      }
    } catch (_) {
      // A failed key validation may also prevent close-time initialization.
      // The enclosing disposable test directory is removed during teardown.
    }
  }
}

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('qaza-powersync-encryption-');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('encrypted database creates, writes, closes, and reopens with same key',
      () async {
    final path = '${temporaryDirectory.path}/encrypted.sqlite';
    final key = _keyWithSeed(0);

    expect(base64Url.decode(key), hasLength(32));

    final first = _openDatabase(path: path, key: key);
    await first.initialize();
    await first.execute(
      'INSERT INTO poc_records (id, label) VALUES (?, ?)',
      ['record-1', 'synthetic-encrypted-poc-record'],
    );
    final row = await first.get(
      'SELECT label FROM poc_records WHERE id = ?',
      ['record-1'],
    );
    expect(row['label'], 'synthetic-encrypted-poc-record');
    await first.close();

    final header = await _readHeader(path);
    expect(header, hasLength(16));
    expect(
      String.fromCharCodes(header),
      isNot('SQLite format 3\u0000'),
      reason: 'Encrypted database must not have the plaintext SQLite header.',
    );

    final reopened = _openDatabase(path: path, key: key);
    await reopened.initialize();
    final persisted = await reopened.get(
      'SELECT label FROM poc_records WHERE id = ?',
      ['record-1'],
    );
    expect(persisted['label'], 'synthetic-encrypted-poc-record');
    await reopened.close();
  });

  test('wrong or missing key fails closed without replacing encrypted file',
      () async {
    final path = '${temporaryDirectory.path}/wrong-key.sqlite';
    final key = _keyWithSeed(0);

    final database = _openDatabase(path: path, key: key);
    await database.initialize();
    await database.execute(
      'INSERT INTO poc_records (id, label) VALUES (?, ?)',
      ['record-1', 'must-survive-key-probe'],
    );
    await database.close();

    final file = File(path);
    final originalBytes = await file.readAsBytes();
    expect(originalBytes, isNotEmpty);

    final wrongKeyFailure =
        await _tryOpenAndRead(path: path, key: _keyWithSeed(91));
    expect(wrongKeyFailure, isNotNull);
    expect(
      await file.readAsBytes(),
      equals(originalBytes),
      reason: 'A wrong-key attempt must not replace or rewrite the original file.',
    );

    final noKeyFailure = await _tryOpenAndRead(path: path);
    expect(noKeyFailure, isNotNull);
    expect(
      await file.readAsBytes(),
      equals(originalBytes),
      reason: 'A no-key attempt must not replace or rewrite the original file.',
    );
  });
}
