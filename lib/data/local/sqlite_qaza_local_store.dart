import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/entities/qaza_ledger_summary.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import 'qaza_local_store.dart';

class SqliteQazaLocalStore implements QazaLocalStore {
  SqliteQazaLocalStore({this.databaseName = 'qaza_namaz.sqlite'});

  static const _version = 2;
  static const _migrationName = 'shared_preferences_v1';
  static const _legacyKey = 'qaza_offline_cache_v1';
  final String databaseName;
  Database? _database;

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final path = await getDatabasesPath();
    _database = await openDatabase(
      p.join(path, databaseName),
      version: _version,
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: (db, old, _) async {
        if (old < 2) await db.execute('CREATE TABLE IF NOT EXISTS qaza_meta (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
    await _migrateLegacyIfNeeded(_database!);
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('CREATE TABLE qaza_meta (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('CREATE TABLE qaza_records (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, prayer_type TEXT NOT NULL, original_date TEXT NOT NULL, status TEXT NOT NULL, completed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.execute('CREATE INDEX idx_qaza_user_date ON qaza_records(user_id, original_date DESC, id DESC)');
    await db.execute('CREATE INDEX idx_qaza_user_prayer ON qaza_records(user_id, prayer_type, original_date DESC, id DESC)');
    await db.execute('CREATE INDEX idx_qaza_user_status ON qaza_records(user_id, status, original_date DESC, id DESC)');
    await db.execute('CREATE TABLE qaza_outbox (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL)');
    await db.execute('CREATE INDEX idx_qaza_outbox_user ON qaza_outbox(user_id)');
    await db.execute('CREATE TABLE qaza_sync_meta (user_id TEXT PRIMARY KEY, last_sync TEXT)');
  }

  Future<void> _migrateLegacyIfNeeded(Database db) async {
    if ((await db.query('qaza_meta', where: 'name = ?', whereArgs: [_migrationName], limit: 1)).isNotEmpty) return;
    final raw = (await SharedPreferences.getInstance()).getString(_legacyKey);
    if (raw == null || raw.isEmpty) {
      await db.insert('qaza_meta', {'name': _migrationName, 'value': 'empty'}, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final users = decoded['recordsByUser'] as Map<String, dynamic>? ?? {};
    final outbox = decoded['outboxByUser'] as Map<String, dynamic>? ?? {};
    final sync = decoded['lastSyncByUser'] as Map<String, dynamic>? ?? {};
    await db.transaction((txn) async {
      for (final entry in users.entries) for (final item in entry.value as List<dynamic>) {
        final record = QazaRecord.fromJson(item as Map<String, dynamic>);
        await txn.insert('qaza_records', _recordValues(record), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final entry in outbox.entries) for (final item in entry.value as List<dynamic>) {
        final op = PendingSyncOp.fromJson(item as Map<String, dynamic>);
        await txn.insert('qaza_outbox', {'id': op.id, 'user_id': op.userId, 'payload': jsonEncode(op.toJson())}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final entry in sync.entries) if (entry.value is String && (entry.value as String).isNotEmpty) {
        await txn.insert('qaza_sync_meta', {'user_id': entry.key, 'last_sync': entry.value}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('qaza_meta', {'name': _migrationName, 'value': 'complete'}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Map<String, Object?> _recordValues(QazaRecord r) => {
        'id': r.id, 'user_id': r.userId, 'prayer_type': r.prayerType.name,
        'original_date': _dateKey(r.originalDate), 'status': r.status.name,
        'completed_at': r.completedAt?.toIso8601String(),
        'created_at': r.createdAt.toIso8601String(), 'updated_at': r.updatedAt.toIso8601String(),
      };

  QazaRecord _recordFromRow(Map<String, Object?> row) => QazaRecord(
        id: row['id']! as String, userId: row['user_id']! as String,
        prayerType: PrayerType.values.firstWhere((v) => v.name == row['prayer_type']),
        originalDate: DateTime.parse(row['original_date']! as String),
        status: QazaStatus.values.firstWhere((v) => v.name == row['status']),
        completedAt: row['completed_at'] == null ? null : DateTime.parse(row['completed_at']! as String),
        createdAt: DateTime.parse(row['created_at']! as String), updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  PendingSyncOp _opFromRow(Map<String, Object?> row) => PendingSyncOp.fromJson(jsonDecode(row['payload']! as String) as Map<String, dynamic>);

  @override
  Future<OfflineCacheSnapshot> load() async {
    final db = await _db();
    final rows = await db.query('qaza_records', orderBy: 'original_date ASC, id ASC');
    final records = <String, List<QazaRecord>>{};
    for (final row in rows) { final r = _recordFromRow(row); records.putIfAbsent(r.userId, () => []).add(r); }
    final ops = await db.query('qaza_outbox', orderBy: 'id ASC');
    final outbox = <String, List<PendingSyncOp>>{};
    for (final row in ops) { final op = _opFromRow(row); outbox.putIfAbsent(op.userId, () => []).add(op); }
    final syncRows = await db.query('qaza_sync_meta');
    final sync = <String, DateTime>{};
    for (final row in syncRows) { final value = row['last_sync'] as String?; if (value != null) sync[row['user_id']! as String] = DateTime.parse(value); }
    return OfflineCacheSnapshot(recordsByUser: records, outboxByUser: outbox, lastSyncByUser: sync);
  }

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    final db = await _db();
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (prayerType != null) { where.add('prayer_type = ?'); args.add(prayerType.name); }
    if (status != null) { where.add('status = ?'); args.add(status.name); }
    final rows = await db.query('qaza_records', where: where.join(' AND '), whereArgs: args, orderBy: 'original_date ASC, id ASC');
    return rows.map(_recordFromRow).toList(growable: false);
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({required String userId, required Iterable<String> recordIds}) async {
    final ids = recordIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const [];
    final db = await _db();
    final result = <QazaRecord>[];
    for (final chunk in _chunks(ids, 400)) {
      final rows = await db.query('qaza_records', where: 'user_id = ? AND id IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: [userId, ...chunk], orderBy: 'original_date ASC, id ASC');
      result.addAll(rows.map(_recordFromRow));
    }
    return List.unmodifiable(result);
  }

  Iterable<List<T>> _chunks<T>(Iterable<T> values, int size) {
    final list = values.toList(growable: false);
    return Iterable.generate((list.length / size).ceil(), (i) => list.sublist(i * size, (i + 1) * size > list.length ? list.length : (i + 1) * size));
  }

  @override
  Future<List<QazaRecord>> getRecordsForDates({required String userId, required Iterable<DateTime> dates, PrayerType? prayerType, QazaStatus? status}) async {
    final wanted = dates.map(_dateKey).toSet();
    if (wanted.isEmpty) return const [];
    final db = await _db();
    final result = <QazaRecord>[];
    for (final chunk in _chunks(wanted, 400)) {
      final where = <String>['user_id = ?', 'original_date IN (${List.filled(chunk.length, '?').join(',')})'];
      final args = <Object?>[userId, ...chunk];
      if (prayerType != null) { where.add('prayer_type = ?'); args.add(prayerType.name); }
      if (status != null) { where.add('status = ?'); args.add(status.name); }
      final rows = await db.query('qaza_records', where: where.join(' AND '), whereArgs: args, orderBy: 'original_date ASC, id ASC');
      result.addAll(rows.map(_recordFromRow));
    }
    return List.unmodifiable(result);
  }

  @override
  Future<DateTime?> getLastSync(String userId) async {
    final db = await _db();
    final rows = await db.query('qaza_sync_meta', columns: ['last_sync'], where: 'user_id = ?', whereArgs: [userId], limit: '1');
    final value = rows.isEmpty ? null : rows.first['last_sync'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  @override
  Future<int> getPendingSyncCount(String userId) async {
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM qaza_outbox WHERE user_id = ?', [userId]);
    return (rows.first['count'] as num).toInt();
  }

  @override
  Future<PendingSyncOp?> getNextPendingSyncOp(String userId) async {
    final db = await _db();
    final rows = await db.query('qaza_outbox', where: 'user_id = ?', whereArgs: [userId], orderBy: 'id ASC', limit: '1');
    return rows.isEmpty ? null : _opFromRow(rows.first);
  }

  @override
  Future<bool> hasPendingCompletion(String userId, String recordId) async {
    final db = await _db();
    final rows = await db.query('qaza_outbox', columns: ['id'], where: 'user_id = ? AND json_extract(payload, \'$.type\') = ? AND json_extract(payload, \'$.targetRecordId\') = ?', whereArgs: [userId, SyncOpType.complete.name, recordId], limit: '1');
    return rows.isNotEmpty;
  }

  @override
  Future<void> deletePendingSyncOp(String userId, String opId) async {
    final db = await _db();
    await db.delete('qaza_outbox', where: 'user_id = ? AND id = ?', whereArgs: [userId, opId]);
  }

  @override
  Future<void> updatePendingSyncOp(String userId, PendingSyncOp op) async {
    final db = await _db();
    await db.update('qaza_outbox', {'payload': jsonEncode(op.toJson())}, where: 'user_id = ? AND id = ?', whereArgs: [userId, op.id]);
  }

  @override
  Future<QazaLedgerSummary> getSummary(String userId) async {
    final db = await _db();
    final statusRows = await db.rawQuery('SELECT status, COUNT(*) AS count FROM qaza_records WHERE user_id = ? GROUP BY status', [userId]);
    var pending = 0, completed = 0;
    for (final row in statusRows) { final count = (row['count'] as num).toInt(); if (row['status'] == QazaStatus.pending.name) pending = count; if (row['status'] == QazaStatus.completed.name) completed = count; }
    final byPrayerRows = await db.rawQuery('SELECT prayer_type, status, COUNT(*) AS count FROM qaza_records WHERE user_id = ? GROUP BY prayer_type, status', [userId]);
    final pendingByPrayer = <PrayerType, int>{};
    final completedByPrayer = <PrayerType, int>{};
    for (final row in byPrayerRows) { final prayer = PrayerType.values.firstWhere((v) => v.name == row['prayer_type']); final count = (row['count'] as num).toInt(); if (row['status'] == QazaStatus.pending.name) pendingByPrayer[prayer] = count; if (row['status'] == QazaStatus.completed.name) completedByPrayer[prayer] = count; }
    return QazaLedgerSummary(total: pending + completed, pending: pending, completed: completed, byPrayer: {for (final prayer in PrayerType.values) prayer: QazaProgress(pending: pendingByPrayer[prayer] ?? 0, completed: completedByPrayer[prayer] ?? 0)});
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    final db = await _db();
    await db.transaction((txn) async { for (final record in records.where((r) => r.userId == userId)) await txn.insert('qaza_records', _recordValues(record), conflictAlgorithm: ConflictAlgorithm.replace); });
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    final db = await _db();
    await db.transaction((txn) async { for (final op in ops.where((o) => o.userId == userId)) await txn.insert('qaza_outbox', {'id': op.id, 'user_id': userId, 'payload': jsonEncode(op.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace); });
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    final db = await _db();
    if (lastSync == null) await db.delete('qaza_sync_meta', where: 'user_id = ?', whereArgs: [userId]);
    else await db.insert('qaza_sync_meta', {'user_id': userId, 'last_sync': lastSync.toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({required String userId, PrayerType? prayerType, QazaStatus? status, DateTime? originalDateFrom, DateTime? originalDateTo, String? cursor, int limit = 25, bool ascending = false}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    final db = await _db();
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (prayerType != null) { where.add('prayer_type = ?'); args.add(prayerType.name); }
    if (status != null) { where.add('status = ?'); args.add(status.name); }
    if (originalDateFrom != null) { where.add('original_date >= ?'); args.add(_dateKey(originalDateFrom)); }
    if (originalDateTo != null) { where.add('original_date <= ?'); args.add(_dateKey(originalDateTo)); }
    if (cursor != null) {
      final cursorRow = await db.query('qaza_records', columns: ['original_date', 'id'], where: 'id = ? AND user_id = ?', whereArgs: [cursor, userId], limit: '1');
      if (cursorRow.isNotEmpty) {
        final date = cursorRow.first['original_date']! as String;
        final id = cursorRow.first['id']! as String;
        where.add(ascending ? '(original_date > ? OR (original_date = ? AND id > ?))' : '(original_date < ? OR (original_date = ? AND id < ?))');
        args.addAll([date, date, id]);
      }
    }
    final order = ascending ? 'original_date ASC, id ASC' : 'original_date DESC, id DESC';
    final rows = await db.query('qaza_records', where: where.join(' AND '), whereArgs: args, orderBy: order, limit: '${limit + 1}');
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    final records = pageRows.map(_recordFromRow).toList(growable: false);
    return QazaHistoryPage(records: records, nextCursor: hasMore && records.isNotEmpty ? records.last.id : null);
  }

  Future<void> close() async { await _database?.close(); _database = null; }
}
