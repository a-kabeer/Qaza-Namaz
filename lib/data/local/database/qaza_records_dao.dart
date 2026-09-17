import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/qaza_records.dart';

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
    return rows.map((row) => row.read(qazaRecords.userId)!).toList(growable: false);
  }

  Future<QazaRecord?> findById({required String userId, required String id}) {
    return (select(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<QazaRecord>> getAll({required String userId}) =>
      getPage(userId: userId, limit: maxPageSize);

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
        if (prayerType != null) predicates.add(row.prayerType.equals(prayerType));
        if (status != null) predicates.add(row.status.equals(status));
        if (from != null) predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        if (to != null) predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([(r) => OrderingTerm.asc(r.originalDate), (r) => OrderingTerm.asc(r.id)])
      ..limit(limit, offset: offset);
    return query.get();
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

  Future<bool> updateRecord(QazaRecord record) => update(qazaRecords).replace(record);

  Future<int> deleteById({required String userId, required String id}) =>
      (delete(qazaRecords)..where((r) => r.userId.equals(userId) & r.id.equals(id))).go();

  void _validatePage(int limit, int offset) {
    if (limit < 1 || limit > maxPageSize) throw ArgumentError.value(limit, 'limit');
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
  }

  void _validateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) throw ArgumentError('from must be <= to');
  }
}
