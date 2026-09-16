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

  static const _version = 1;
  static const _migrationName = 'shared_preferences_v1';
  static const _legacyKey = 'qaza_offline_cache_v1';

  final String databaseName;
  Database? _database;

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    _database = await openDatabase(p.join(databasesPath, databaseName), version: _version, onCreate: (db, _) async {
      await db.execute('CREATE TABLE qaza_meta (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
      await db.execute('''CREATE TABLE qaza_records (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, prayer_type TEXT NOT NULL,
        original_date TEXT NOT NULL, status TEXT NOT NULL, completed_at TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      await db.execute('CREATE INDEX idx_qaza_user_date ON qaza_records(user_id, original_date DESC, id DESC)');
      await db.execute('CREATE INDEX idx_qaza_user_prayer ON qaza_records(user_id, prayer_type, original_date DESC, id DESC)');
      await db.execute('CREATE INDEX idx_qaza_user_status ON qaza_records(user_id, status, original_date DESC, id DESC)');
      await db.execute('CREATE TABLE qaza_outbox (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL)');
      await db.execute('CREATE INDEX idx_qaza_outbox_user ON qaza_outbox(user_id)');
      await db.execute('CREATE TABLE qaza_sync_meta (user_id TEXT PRIMARY KEY, last_sync TEXT)');
    });
    await _migrateLegacyIfNeeded(_database!);
    return _database!;
  }

  Future<void> _migrateLegacyIfNeeded(Database db) async {
    final marker = await db.query('qaza_meta', where: 'name = ?', whereArgs: [_migrationName], limit: 1);
    if (marker.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) {
      await db.insert('qaza_meta', {'name': _migrationName, 'value': 'empty'}, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final users = decoded['recordsByUser'] as Map<String, dynamic>? ?? {};
    final outbox = decoded['outboxByUser'] as Map<String, dynamic>? ?? {};
    final sync = decoded['lastSyncByUser'] as Map<String, dynamic>? ?? {};
    await db.transaction((txn) async {
      for (final entry in users.entries) {
        for (final item in entry.value as List<dynamic>) {
          final record = QazaRecord.fromJson(item as Map<String, dynamic>);
          await txn.insert('qaza_records', _recordValues(record), conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final entry in outbox.entries) {
        for (final item in entry.value as List<dynamic>) {
          final op = PendingSyncOp.fromJson(item as Map<String, dynamic>);
          await txn.insert('qaza_outbox', {'id': op.id, 'user_id': op.userId, 'payload': jsonEncode(op.toJson())}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final entry in sync.entries) {
        await txn.insert('qaza_sync_meta', {'user_id': entry.key, 'last_sync': entry.value as String}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('qaza_meta', {'name': _migrationName, 'value': 'complete'}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Map<String, Object?> _recordValues(QazaRecord r) => {
        'id': r.id,
        'user_id': r.userId,
        'prayer_type': r.prayerType.name,
        'original_date': _dateKey(r.originalDate),
        'status': r.status.name,
        'completed_at': r.completedAt?.toIso8601String(),
        'created_at': r.createdAt.toIso8601String(),
        'updated_at': r.updatedAt.toIso8601String(),
      };

  QazaRecord _recordFromRow(Map<String, Object?> row) => QazaRecord(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        prayerType: PrayerType.values.firstWhere((v) => v.name == row['prayer_type']),
        originalDate: DateTime.parse(row['original_date']! as String),
        status: QazaStatus.values.firstWhere((v) => v.name == row['status']),
        completedAt: row['completed_at'] == null ? null : DateTime.parse(row['completed_at']! as String),
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Future<OfflineCacheSnapshot> load() async {
    final db = await _db();
    final rows = await db.query('qaza_records', orderBy: 'original_date ASC, id ASC');
    final records = <String, List<QazaRecord>>{};
    for (final row in rows) {
      final record = _recordFromRow(row);
      records.putIfAbsent(record.userId, () => []).add(record);
    }
    final outboxRows = await db.query('qaza_outbox', orderBy: 'id ASC');
    final outbox = <String, List<PendingSyncOp>>{};
    for (final row in outboxRows) {
      final op = PendingSyncOp.fromJson(jsonDecode(row['payload']! as String) as Map<String, dynamic>);
      outbox.putIfAbsent(op.userId, () => []).add(op);
    }
    final syncRows = await db.query('qaza_sync_meta');
    final sync = <String, DateTime>{};
    for (final row in syncRows) {
      final value = row['last_sync'] as String?;
      if (value != null) sync[row['user_id']! as String] = DateTime.parse(value);
    }
    return OfflineCacheSnapshot(recordsByUser: records, outboxByUser: outbox, lastSyncByUser: sync);
  }

  @override
  Future<QazaLedgerSummary> getSummary(String userId) async {
    final db = await _db();
    final statusRows = await db.rawQuery('SELECT status, COUNT(*) AS count FROM qaza_records WHERE user_id = ? GROUP BY status', [userId]);
    var pending = 0;
    var completed = 0;
    for (final row in statusRows) {
      final count = (row['count'] as num).toInt();
      if (row['status'] == QazaStatus.pending.name) pending = count;
      if (row['status'] == QazaStatus.completed.name) completed = count;
    }
    final byPrayerRows = await db.rawQuery('SELECT prayer_type, status, COUNT(*) AS count FROM qaza_records WHERE user_id = ? GROUP BY prayer_type, status', [userId]);
    final pendingByPrayer = <PrayerType, int>{};
    final completedByPrayer = <PrayerType, int>{};
    for (final row in byPrayerRows) {
      final prayer = PrayerType.values.firstWhere((v) => v.name == row['prayer_type']);
      final count = (row['count'] as num).toInt();
      if (row['status'] == QazaStatus.pending.name) pendingByPrayer[prayer] = count;
      if (row['status'] == QazaStatus.completed.name) completedByPrayer[prayer] = count;
    }
    final byPrayer = <PrayerType, QazaProgress>{
      for (final prayer in PrayerType.values)
        prayer: QazaProgress(pending: pendingByPrayer[prayer] ?? 0, completed: completedByPrayer[prayer] ?? 0),
    };
    return QazaLedgerSummary(total: pending + completed, pending: pending, completed: completed, byPrayer: byPrayer);
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('qaza_records', where: 'user_id = ?', whereArgs: [userId]);
      for (final record in records.where((r) => r.userId == userId)) {
        await txn.insert('qaza_records', _recordValues(record), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('qaza_outbox', where: 'user_id = ?', whereArgs: [userId]);
      for (final op in ops.where((o) => o.userId == userId)) {
        await txn.insert('qaza_outbox', {'id': op.id, 'user_id': userId, 'payload': jsonEncode(op.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    final db = await _db();
    if (lastSync == null) {
      await db.delete('qaza_sync_meta', where: 'user_id = ?', whereArgs: [userId]);
    } else {
      await db.insert('qaza_sync_meta', {'user_id': userId, 'last_sync': lastSync.toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
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
        if (ascending) { where.add('(original_date > ? OR (original_date = ? AND id > ?))'); args.addAll([date, date, id]); }
        else { where.add('(original_date < ? OR (original_date = ? AND id < ?))'); args.addAll([date, date, id]); }
      }
    }
    final order = ascending ? 'original_date ASC, id ASC' : 'original_date DESC, id DESC';
    final rows = await db.query('qaza_records', where: where.join(' AND '), whereArgs: args, orderBy: order, limit: '${limit + 1}');
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    final records = pageRows.map(_recordFromRow).toList(growable: false);
    return QazaHistoryPage(records: records, nextCursor: hasMore && records.isNotEmpty ? records.last.id : null);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
