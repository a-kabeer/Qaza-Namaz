import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/qaza_records.dart';

/// Database-only access for Qaza records.
///
/// This DAO deliberately returns database rows rather than domain entities.
/// Repository mapping and business rules belong to the repository/service
/// layers and will be introduced in Part 4.
@DriftAccessor(tables: [QazaRecords])
class QazaRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$QazaRecordsDaoMixin {
  QazaRecordsDao(super.db);

  Future<QazaRecord?> findById({required String userId, required String id}) {
    return (select(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<QazaRecord>> getPage({
    required String userId,
    int limit = 50,
    int offset = 0,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
  }) {
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

  Future<int> count({
    required String userId,
    String? prayerType,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
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

  Future<int> insertRecord(QazaRecordsCompanion record) =>
      into(qazaRecords).insert(record);

  Future<bool> updateRecord(QazaRecordsCompanion record) =>
      update(qazaRecords).replace(record);

  Future<int> deleteById({required String userId, required String id}) {
    return (delete(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .go();
  }
}
