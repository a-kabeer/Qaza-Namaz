import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates a plaintext sqlite database to an encrypted database', () async {
    final directory = await Directory.systemTemp.createTemp('qaza_db_test_');
    addTearDown(() => directory.delete(recursive: true));

    final databaseFile = File('${directory.path}/qaza_namaz.sqlite');
    final plaintext = sqlite3.open(databaseFile.path);
    try {
      plaintext.execute(
        'CREATE TABLE sample (id INTEGER PRIMARY KEY, value TEXT);',
      );
      plaintext.execute(
        "INSERT INTO sample (value) VALUES ('sensitive qaza row');",
      );
    } finally {
      plaintext.close();
    }

    const key =
        'cWpheF9uYW1hel9sb2NhbF9kYl9lbmNyeXB0aW9uX2tleV8yNTZiaXRzXzEyMw==';

    await PlaintextDatabaseMigrator.migrateIfNeeded(
      databaseFile: databaseFile,
      key: key,
    );

    final raf = await databaseFile.open();
    final bytes = await raf.read(16);
    await raf.close();

    expect(
      String.fromCharCodes(bytes),
      isNot(startsWith('SQLite format 3')),
    );

    final encrypted = sqlite3.open(databaseFile.path);
    try {
      encrypted.execute("PRAGMA key = '$key';");
      final rows = encrypted.select('SELECT value FROM sample;');
      expect(rows.single['value'], 'sensitive qaza row');
    } finally {
      encrypted.close();
    }
  });
}
