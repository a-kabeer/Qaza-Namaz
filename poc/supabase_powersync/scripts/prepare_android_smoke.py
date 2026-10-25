#!/usr/bin/env python3
"""Create a throwaway Android host and encryption smoke test for Run A."""
from pathlib import Path
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare_android_smoke.py ANDROID_APP_DIR")

app = Path(sys.argv[1]).resolve()
subprocess.run(
    ["flutter", "create", "--platforms=android", "--project-name",
     "qaza_powersync_android_smoke", str(app)],
    check=True,
)
pubspec = app / "pubspec.yaml"
text = pubspec.read_text(encoding="utf-8")
text = text.replace(
    "dependencies:\n",
    "dependencies:\n  powersync: 2.5.0\n  path_provider: ^2.1.5\n",
    1,
)
text = text.replace(
    "dev_dependencies:\n",
    "dev_dependencies:\n  integration_test:\n    sdk: flutter\n",
    1,
)
text += "\nhooks:\n  user_defines:\n    sqlite3:\n      source: sqlite3mc\n"
pubspec.write_text(text, encoding="utf-8")

(app / "integration_test").mkdir(parents=True, exist_ok=True)
(app / "lib" / "main.dart").write_text(
    "import 'package:flutter/material.dart';\n"
    "void main() => runApp(const MaterialApp(home: Scaffold(body: Text('PowerSync encryption PoC'))));\n",
    encoding="utf-8",
)
(app / "integration_test" / "powersync_encryption_test.dart").write_text(r"""
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

const schema = Schema([
  Table('android_smoke_records', [Column.text('label')]),
]);

String keyFor(int seed) =>
    base64UrlEncode(List<int>.generate(32, (i) => (i + seed) & 0xff));

PowerSyncDatabase openDb(String path, {String? key}) => PowerSyncDatabase(
      schema: schema,
      path: path,
      encryption: key == null
          ? null
          : EncryptionOptions(key: key, sqlcipherCompatibility: false),
    );

Future<Object?> tryOpen(String path, {String? key}) async {
  PowerSyncDatabase? db;
  try {
    db = openDb(path, key: key);
    await db.initialize();
    await db.get('SELECT label FROM android_smoke_records LIMIT 1');
    return null;
  } catch (error) {
    return error;
  } finally {
    try {
      if (db != null && !db.closed) await db.close();
    } catch (_) {}
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android encrypted database persists and rejects wrong keys', (tester) async {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}${Platform.pathSeparator}powersync-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final key = keyFor(0);

    final db = openDb(path, key: key);
    await db.initialize();
    expect((await db.getUploadQueueStats()).count, 0);
    await db.execute(
      'INSERT INTO android_smoke_records (id, label) VALUES (?, ?)',
      ['android-record-1', 'synthetic-android-encrypted-record'],
    );
    expect((await db.getUploadQueueStats()).count, 1);
    await db.close();

    final file = File(path);
    final original = await file.readAsBytes();
    expect(original, isNotEmpty);
    expect(
      String.fromCharCodes(original.take(16)),
      isNot('SQLite format 3\u0000'),
      reason: 'Encrypted SQLite file must not have the plaintext header.',
    );

    final reopened = openDb(path, key: key);
    await reopened.initialize();
    expect((await reopened.getUploadQueueStats()).count, 1);
    final row = await reopened.get(
      'SELECT label FROM android_smoke_records WHERE id = ?',
      ['android-record-1'],
    );
    expect(row['label'], 'synthetic-android-encrypted-record');
    await reopened.close();

    final wrongCopy = await file.copy('$path.wrong-key-copy');
    final wrongBytes = await wrongCopy.readAsBytes();
    expect(await tryOpen(wrongCopy.path, key: keyFor(71)), isNotNull);
    expect(await wrongCopy.readAsBytes(), equals(wrongBytes));

    final noKeyCopy = await file.copy('$path.no-key-copy');
    final noKeyBytes = await noKeyCopy.readAsBytes();
    expect(await tryOpen(noKeyCopy.path), isNotNull);
    expect(await noKeyCopy.readAsBytes(), equals(noKeyBytes));
    expect(await file.readAsBytes(), equals(original));
  });
}
""".lstrip(), encoding="utf-8")
