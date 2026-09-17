import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/qaza_records.dart';

/// Database-only access for Qaza records.
///
/// Queries are always scoped by Firebase user ID and execute in SQLite. This
/// prevents the repository from loading the complete ledger into memory.
@DriftAccessor(tables: [QazaRecords])
class QazaRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$QazaRecordsDaoMixin {
  QazaRecordsDao(super.db);

  static const int defaultPageSize = 50;
  static const int maxPageSize = 500;

  Future<QazaRecord?> findById({required String userId, required String id}) {
    return (select(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<QazaRecord>> getPage({
    required String userId,
    int limit = defaultPageSize,
    int offset = 0,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
  }) {
    _validatePage(limit, offset);
    _validateRange(from, to);

    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (status != null) {
          predicates.add(row.status.equals(status));
        }
        if (from != null) {
          predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        }
        if (to != null) {
          predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.originalDate),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(limit, offset: offset);

    return query.get();
  }

  Future<List<QazaRecord>> getPendingPage({
    required String userId,
    int limit = defaultPageSize,
    int offset = 0,
    String? prayerType,
  }) =>
      getPage(
        userId: userId,
        limit: limit,
        offset: offset,
        prayerType: prayerType,
        status: 'pending',
      );

  Future<List<QazaRecord>> getCompletedPage({
    required String userId,
    int limit = defaultPageSize,
    int offset = 0,
    String? prayerType,
  }) =>
      getPage(
        userId: userId,
        limit: limit,
        offset: offset,
        prayerType: prayerType,
        status: 'completed',
      );

  Future<List<QazaRecord>> getByDateRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    int limit = defaultPageSize,
    int offset = 0,
  }) =>
      getPage(
        userId: userId,
        limit: limit,
        offset: offset,
        from: from,
        to: to,
      );

  Future<List<QazaRecord>> getByPrayerAndDateRange({
    required String userId,
    required String prayerType,
    required DateTime from,
    required DateTime to,
    int limit = defaultPageSize,
    int offset = 0,
  }) =>
      getPage(
        userId: userId,
        limit: limit,
        offset: offset,
        prayerType: prayerType,
        from: from,
        to: to,
      );

  Future<QazaRecord?> getOldestPending({
    required String userId,
    String? prayerType,
  }) async {
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[
          row.userId.equals(userId),
          row.status.equals('pending'),
        ];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.originalDate),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<int> count({
    required String userId,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    _validateRange(from, to);
    final query = selectOnly(qazaRecords)
      ..addColumns([qazaRecords.id.count()])
      ..where(qazaRecords.userId.equals(userId));

    if (prayerType != null) {
      query.where(qazaRecords.prayerType.equals(prayerType));
    }
    if (status != null) {
      query.where(qazaRecords.status.equals(status));
    }
    if (from != null) {
      query.where(qazaRecords.originalDate.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(qazaRecords.originalDate.isSmallerOrEqualValue(to));
    }

    return (await query.getSingle()).read(qazaRecords.id.count()) ?? 0;
  }

  Future<int> countPending({
    required String userId,
    String? prayerType,
  }) =>
      count(userId: userId, prayerType: prayerType, status: 'pending');

  Future<int> countCompleted({
    required String userId,
    String? prayerType,
  }) =>
      count(userId: userId, prayerType: prayerType, status: 'completed');

  Future<int> insertRecord(QazaRecordsCompanion record) =>
      into(qazaRecords).insert(record);

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

  Future<bool> updateRecord(QazaRecordsCompanion record) =>
      update(qazaRecords).replace(record);

  Future<int> deleteById({required String userId, required String id}) {
    return (delete(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .go();
  }

  void _validatePage(int limit, int offset) {
    if (limit < 1 || limit > maxPageSize) {
      throw ArgumentError.value(
        limit,
        'limit',
        'must be between 1 and $maxPageSize',
      );
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must be >= 0');
    }
  }

  void _validateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be earlier than or equal to to');
    }
  }
}
