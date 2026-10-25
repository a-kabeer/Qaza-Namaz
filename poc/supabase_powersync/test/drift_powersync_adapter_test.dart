import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';

part 'drift_powersync_adapter_test.g.dart';

class PocRecords extends drift.Table {
  @override
  String get tableName => 'poc_records';

  drift.TextColumn get id => text()();
  drift.TextColumn get label => text()();

  @override
  Set<drift.Column> get primaryKey => {id};
}

@drift.DriftDatabase(tables: [PocRecords])
class PocDriftDatabase extends _$PocDriftDatabase {
  PocDriftDatabase(SqliteConnection connection)
      : super(SqliteAsyncDriftConnection(connection));

  @override
  int get schemaVersion => 1;

  // PowerSync owns and creates the synced table/view. Drift manages typed
  // access and query generation but must not create a competing SQLite table.
  @override
  drift.MigrationStrategy get migration => drift.MigrationStrategy(
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );
}

const _schema = Schema([
  Table('poc_records', [
    Column.text('label'),
  ]),
]);

String _testKey() =>
    base64UrlEncode(List<int>.generate(32, (i) => i & 0xff));

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('qaza-powersync-drift-');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('Drift reads and writes PowerSync-managed encrypted tables', () async {
    final path = '${temporaryDirectory.path}/drift-adapter.sqlite';
    final key = _testKey();
    final powerSync = PowerSyncDatabase(
      schema: _schema,
      path: path,
      encryption: EncryptionOptions(key: key, sqlcipherCompatibility: false),
    );
    await powerSync.initialize();

    final driftDb = PocDriftDatabase(powerSync);
    await driftDb.into(driftDb.pocRecords).insert(
          PocRecordsCompanion.insert(
            id: 'drift-1',
            label: 'written-through-drift',
          ),
        );

    final fromPowerSync = await powerSync.get(
      'SELECT label FROM poc_records WHERE id = ?',
      ['drift-1'],
    );
    expect(fromPowerSync['label'], 'written-through-drift');

    final watcher = StreamQueue(driftDb.select(driftDb.pocRecords).watch());
    final initial = await watcher.next.timeout(const Duration(seconds: 5));
    expect(initial.map((row) => row.id), contains('drift-1'));

    await powerSync.execute(
      'INSERT INTO poc_records (id, label) VALUES (?, ?)',
      ['powersync-1', 'written-through-powersync'],
    );
    final updated = await watcher.next.timeout(const Duration(seconds: 5));
    expect(updated.map((row) => row.id), containsAll(['drift-1', 'powersync-1']));
    expect(
      updated.firstWhere((row) => row.id == 'powersync-1').label,
      'written-through-powersync',
    );
    await watcher.cancel();

    await driftDb.close();

    final reopened = PowerSyncDatabase(
      schema: _schema,
      path: path,
      encryption: EncryptionOptions(key: key, sqlcipherCompatibility: false),
    );
    await reopened.initialize();
    final persisted = await reopened.get(
      'SELECT label FROM poc_records WHERE id = ?',
      ['drift-1'],
    );
    expect(persisted['label'], 'written-through-drift');
    await reopened.close();
  });
}
