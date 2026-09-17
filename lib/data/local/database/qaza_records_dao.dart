import 'package:drift/drift.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_record.dart';
import 'app_database.dart';
import 'tables/qaza_records.dart';

part 'qaza_records_dao.g.dart';

/// A keyset page. The cursor is the last `(originalDate, id)` returned and can
/// be supplied to the next query without an increasingly expensive OFFSET.
class QazaRecordsPage {
  const QazaRecordsPage({required this.records, required this.hasMore});

  final List<QazaRecord> records;
  final bool hasMore;

  DateTime? get nextOriginalDate => records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

/// A newest-first history page using a stable descending `(originalDate, id)`
/// cursor.
class QazaHistoryPage {
  const QazaHistoryPage({required this.records, required this.hasMore});

  final List<QazaRecord> records;
  final bool hasMore;

  DateTime? get nextOriginalDate => records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

@DriftAccessor(tables: [QazaRecords])
class QazaRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$QazaRecordsDaoMixin {
  QazaRecordsDao(super.db);

  static const int defaultPageSize = 50;
  static const int maxPageSize = 500;

  Future<List<String>> userIds() async {
    final query = selectOnly(qazaRecords, distinct: true)
      ..addColumns([qazaRecords.userId]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(qazaRecords.userId)!)
        .toList(growable: false);
  }

  Future<QazaRecord?> findById({required String userId, required String id}) async {
    final row = await (select(qazaRecords)
          ..where((record) =>
              record.userId.equals(userId) & record.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<QazaRecord>> getAll({required String userId}) async {
    final records = <QazaRecord>[];
    var offset = 0;
    while (true) {
      final page = await getPage(userId: userId, limit: maxPageSize, offset: offset);
      records.addAll(page);
      if (page.length < maxPageSize) return records;
      offset += page.length;
    }
  }

  Future<QazaRecordsPage> getKeysetPage({
    required String userId,
    int limit = defaultPageSize,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) async {
    _validatePage(limit, 0);
    _validateRange(from, to);
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError('afterOriginalDate and afterId must be provided together');
    }

    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) predicates.add(row.prayerType.equals(prayerType));
        if (status != null) predicates.add(row.status.equals(status));
        if (from != null) predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        if (to != null) predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        if (afterOriginalDate != null) {
          predicates.add(
            row.originalDate.isBiggerThanValue(afterOriginalDate) |
                (row.originalDate.equals(afterOriginalDate) &
                    row.id.isBiggerThanValue(afterId!)),
          );
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.asc(r.originalDate),
        (r) => OrderingTerm.asc(r.id),
      ])
      ..limit(limit + 1);

    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    final visible = visibleRows.map(_toDomain).toList(growable: false);
    return QazaRecordsPage(records: visible, hasMore: hasMore);
  }

  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = defaultPageSize,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    _validatePage(limit, 0);
    _validateRange(from, to);
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError('beforeOriginalDate and beforeId must be provided together');
    }

    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) predicates.add(row.prayerType.equals(prayerType));
        if (status != null) predicates.add(row.status.equals(status));
        if (from != null) predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        if (to != null) predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        if (beforeOriginalDate != null) {
          predicates.add(
            row.originalDate.isSmallerThanValue(beforeOriginalDate) |
                (row.originalDate.equals(beforeOriginalDate) &
                    row.id.isSmallerThanValue(beforeId!)),
          );
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.desc(r.originalDate),
        (r) => OrderingTerm.desc(r.id),
      ])
      ..limit(limit + 1);

    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    final visible = visibleRows.map(_toDomain).toList(growable: false);
    return QazaHistoryPage(records: visible, hasMore: hasMore);
  }

  /// Database-side grouped counts used by History progress cards. No Qaza
  /// rows are materialized by the caller.
  Future<Map<PrayerType, Map<QazaStatus, int>>> getProgressCounts({
    required String userId,
  }) async {
    final countExpression = qazaRecords.id.count();
    final query = selectOnly(qazaRecords)
      ..addColumns([
        qazaRecords.prayerType,
        qazaRecords.status,
        countExpression,
      ])
      ..where(qazaRecords.userId.equals(userId))
      ..groupBy([qazaRecords.prayerType, qazaRecords.status]);

    final rows = await query.get();
    final counts = <PrayerType, Map<QazaStatus, int>>{};
    for (final row in rows) {
      final prayerName = row.read(qazaRecords.prayerType);
      final statusName = row.read(qazaRecords.status);
      final count = row.read(countExpression) ?? 0;
      if (prayerName == null || statusName == null) continue;

      final prayer = PrayerType.values.firstWhere(
        (value) => value.name == prayerName,
        orElse: () => throw StateError('Unknown prayer type "$prayerName" in local database.'),
      );
      final status = QazaStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => throw StateError('Unknown Qaza status "$statusName" in local database.'),
      );
      counts.putIfAbsent(prayer, () => <QazaStatus, int>{})[status] = count;
    }
    return counts;
  }

  Future<List<QazaRecord>> getPage({
    required String userId,
    int limit = defaultPageSize,
    int offset = 0,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    _validatePage(limit, offset);
    _validateRange(from, to);
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) predicates.add(row.prayerType.equals(prayerType));
        if (status != null) predicates.add(row.status.equals(status));
        if (from != null) predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        if (to != null) predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.asc(r.originalDate),
        (r) => OrderingTerm.asc(r.id),
      ])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Compatibility helpers retained for the pre-migration Qaza-list code.
  Future<List<QazaRecord>> getByPrayerAndDateRange({
    required String userId,
    required String prayerType,
    required DateTime from,
    required DateTime to,
  }) => getPage(
        userId: userId,
        limit: maxPageSize,
        prayerType: prayerType,
        from: from,
        to: to,
      );

  Future<List<QazaRecord>> getPendingPage({
    required String userId,
    String? prayerType,
    int limit = maxPageSize,
  }) => getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: QazaStatus.pending.name,
      );

  Future<List<QazaRecord>> getCompletedPage({
    required String userId,
    String? prayerType,
    int limit = maxPageSize,
  }) => getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: QazaStatus.completed.name,
      );

  Future<int> countPending({required String userId, String? prayerType}) =>
      count(userId: userId, prayerType: prayerType, status: QazaStatus.pending.name);

  Future<int> countCompleted({required String userId, String? prayerType}) =>
      count(userId: userId, prayerType: prayerType, status: QazaStatus.completed.name);

  Future<QazaRecord?> getOldestPending({required String userId, String? prayerType}) async {
    final rows = await getPage(
      userId: userId,
      limit: 1,
      prayerType: prayerType,
      status: QazaStatus.pending.name,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> replaceUserRecords({
    required String userId,
    required List<QazaRecordsCompanion> records,
  }) async {
    await (delete(qazaRecords)..where((r) => r.userId.equals(userId))).go();
    for (final record in records) {
      await into(qazaRecords).insert(record);
    }
  }

  Future<int> count({required String userId, String? prayerType, String? status}) async {
    final query = selectOnly(qazaRecords)
      ..addColumns([qazaRecords.id.count()])
      ..where(qazaRecords.userId.equals(userId));
    if (prayerType != null) query.where(qazaRecords.prayerType.equals(prayerType));
    if (status != null) query.where(qazaRecords.status.equals(status));
    return (await query.getSingle()).read(qazaRecords.id.count()) ?? 0;
  }

  Future<int> insertRecord(QazaRecordsCompanion record) => into(qazaRecords).insert(record);

  Future<int> insertRecords(List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return 0;
    return transaction(() async {
      var inserted = 0;
      for (final record in records) {
        await into(qazaRecords).insert(record);
        inserted++;
      }
      return inserted;
    });
  }

  Future<bool> updateRecord(QazaRecord record) =>
      update(qazaRecords).replace(_toCompanion(record));

  Future<int> deleteById({required String userId, required String id}) =>
      (delete(qazaRecords)..where((r) => r.userId.equals(userId) & r.id.equals(id))).go();

  QazaRecord _toDomain(QazaRecordRow row) {
    return QazaRecord(
      id: row.id,
      userId: row.userId,
      prayerType: PrayerType.values.firstWhere(
        (value) => value.name == row.prayerType,
        orElse: () => throw StateError('Unknown prayer type "${row.prayerType}" in local database.'),
      ),
      originalDate: row.originalDate,
      status: QazaStatus.values.firstWhere(
        (value) => value.name == row.status,
        orElse: () => throw StateError('Unknown Qaza status "${row.status}" in local database.'),
      ),
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  QazaRecordsCompanion _toCompanion(QazaRecord record) {
    return QazaRecordsCompanion.insert(
      id: record.id,
      userId: record.userId,
      prayerType: record.prayerType.name,
      originalDate: record.originalDate,
      status: record.status.name,
      completedAt: record.completedAt == null
          ? const Value.absent()
          : Value(record.completedAt),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  void _validatePage(int limit, int offset) {
    if (limit < 1 || limit > maxPageSize) throw ArgumentError.value(limit, 'limit');
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
  }

  void _validateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
  }
}
