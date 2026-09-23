import 'package:drift/drift.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/repositories/qaza_recovery_repository.dart';
import 'app_database.dart';
import 'tables/qaza_records.dart';

part 'qaza_records_dao.g.dart';

class QazaRecordsPage {
  const QazaRecordsPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

class QazaHistoryPage {
  const QazaHistoryPage({required this.records, required this.hasMore});
  final List<QazaRecord> records;
  final bool hasMore;
  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
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

  Future<List<QazaRecordRow>> getRowsByIds({
    required String userId,
    required List<String> ids,
  }) {
    if (ids.isEmpty) return Future.value(const <QazaRecordRow>[]);
    final wanted = ids.toSet().toList(growable: false);
    return (select(qazaRecords)
          ..where((row) => row.userId.equals(userId) & row.id.isIn(wanted)))
        .get();
  }

  Future<QazaRecord?> findById(
      {required String userId, required String id}) async {
    final row = await (select(qazaRecords)
          ..where(
              (record) => record.userId.equals(userId) & record.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<QazaRecord>> getAll({required String userId}) async {
    final records = <QazaRecord>[];
    DateTime? cursorDate;
    String? cursorId;
    while (true) {
      final page = await getKeysetPage(
        userId: userId,
        limit: maxPageSize,
        afterOriginalDate: cursorDate,
        afterId: cursorId,
      );
      records.addAll(page.records);
      if (!page.hasMore) return records;
      cursorDate = page.nextOriginalDate!;
      cursorId = page.nextId!;
    }
  }

  Future<QazaRecordsPage> getKeysetPage(
      {required String userId,
      int limit = defaultPageSize,
      String? prayerType,
      String? status,
      DateTime? from,
      DateTime? to,
      DateTime? afterOriginalDate,
      String? afterId}) async {
    _validatePage(limit, 0);
    _validateRange(from, to);
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    }
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (status == QazaStatus.deleted.name) {
          predicates.add(row.status.equals(QazaStatus.deleted.name));
        } else {
          predicates.add(row.status.isNotIn(
              [QazaStatus.deleted.name]));
          if (status != null) predicates.add(row.status.equals(status));
        }
        if (from != null) {
          predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        }
        if (to != null) {
          predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        }
        if (afterOriginalDate != null) {
          predicates.add(row.originalDate.isBiggerThanValue(afterOriginalDate) |
              (row.originalDate.equals(afterOriginalDate) &
                  row.id.isBiggerThanValue(afterId!)));
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.asc(r.originalDate),
        (r) => OrderingTerm.asc(r.id)
      ])
      ..limit(limit + 1);
    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    return QazaRecordsPage(
        records: visibleRows.map(_toDomain).toList(growable: false),
        hasMore: hasMore);
  }

  Future<QazaHistoryPage> getHistoryPage(
      {required String userId,
      int limit = defaultPageSize,
      String? prayerType,
      String? status,
      DateTime? from,
      DateTime? to,
      DateTime? beforeOriginalDate,
      String? beforeId}) async {
    _validatePage(limit, 0);
    _validateRange(from, to);
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError(
          'beforeOriginalDate and beforeId must be provided together');
    }
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (status == QazaStatus.deleted.name) {
          predicates.add(row.status.equals(QazaStatus.deleted.name));
        } else {
          predicates.add(row.status.isNotIn(
              [QazaStatus.deleted.name]));
          if (status != null) predicates.add(row.status.equals(status));
        }
        if (from != null) {
          predicates.add(row.originalDate.isBiggerOrEqualValue(from));
        }
        if (to != null) {
          predicates.add(row.originalDate.isSmallerOrEqualValue(to));
        }
        if (beforeOriginalDate != null) {
          predicates.add(
              row.originalDate.isSmallerThanValue(beforeOriginalDate) |
                  (row.originalDate.equals(beforeOriginalDate) &
                      row.id.isSmallerThanValue(beforeId!)));
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.desc(r.originalDate),
        (r) => OrderingTerm.desc(r.id)
      ])
      ..limit(limit + 1);
    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    return QazaHistoryPage(
        records: visibleRows.map(_toDomain).toList(growable: false),
        hasMore: hasMore);
  }

  Future<Map<PrayerType, Map<QazaStatus, int>>> getProgressCounts(
      {required String userId}) async {
    final countExpression = qazaRecords.id.count();
    final query = selectOnly(qazaRecords)
      ..addColumns(
          [qazaRecords.prayerType, qazaRecords.status, countExpression])
      ..where(qazaRecords.userId.equals(userId) &
          qazaRecords.status.isIn([
            QazaStatus.pending.name,
            QazaStatus.completed.name,
          ]))
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
          orElse: () => throw StateError(
              'Unknown prayer type "$prayerName" in local database.'));
      final status = QazaStatus.values.firstWhere(
          (value) => value.name == statusName,
          orElse: () => throw StateError(
              'Unknown Qaza status "$statusName" in local database.'));
      counts.putIfAbsent(prayer, () => <QazaStatus, int>{})[status] = count;
    }
    return counts;
  }

  Future<List<QazaRecord>> getPage(
      {required String userId,
      int limit = defaultPageSize,
      int offset = 0,
      String? prayerType,
      String? status,
      DateTime? from,
      DateTime? to}) async {
    _validatePage(limit, offset);
    _validateRange(from, to);
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (status == QazaStatus.deleted.name) {
          predicates.add(row.status.equals(QazaStatus.deleted.name));
        } else {
          predicates.add(row.status.isNotIn(
              [QazaStatus.deleted.name]));
          if (status != null) predicates.add(row.status.equals(status));
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
        (r) => OrderingTerm.asc(r.originalDate),
        (r) => OrderingTerm.asc(r.id)
      ])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<List<QazaRecord>> getByPrayerAndDateRange(
          {required String userId,
          required String prayerType,
          required DateTime from,
          required DateTime to}) =>
      getPage(
          userId: userId,
          limit: maxPageSize,
          prayerType: prayerType,
          from: from,
          to: to);
  Future<List<QazaRecord>> getPendingPage(
          {required String userId,
          String? prayerType,
          int limit = maxPageSize}) =>
      getPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: QazaStatus.pending.name);
  Future<List<QazaRecord>> getCompletedPage(
          {required String userId,
          String? prayerType,
          int limit = maxPageSize}) =>
      getPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: QazaStatus.completed.name);
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) {
      throw ArgumentError('from must be before to');
    }
    final countExpression = qazaRecords.id.count();
    final query = selectOnly(qazaRecords)
      ..addColumns([countExpression])
      ..where(
        qazaRecords.userId.equals(userId) &
            qazaRecords.status.equals(QazaStatus.completed.name) &
            qazaRecords.completedAt.isBiggerOrEqualValue(from) &
            qazaRecords.completedAt.isSmallerThanValue(to),
      );
    return (await query.getSingle()).read(countExpression) ?? 0;
  }

  Future<bool> hasRecordCombination({
    required String userId,
    required String prayerType,
    required DateTime originalDate,
    String? excludingRecordId,
  }) async {
    final query = select(qazaRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.prayerType.equals(prayerType) &
            row.originalDate.equals(originalDate) &
            row.status.isNotIn([QazaStatus.deleted.name]),
      )
      ..limit(2);
    final rows = await query.get();
    return rows.any((row) => row.id != excludingRecordId);
  }

  Future<int> countPending({required String userId, String? prayerType}) =>
      count(
          userId: userId,
          prayerType: prayerType,
          status: QazaStatus.pending.name);
  Future<int> countCompleted({required String userId, String? prayerType}) =>
      count(
          userId: userId,
          prayerType: prayerType,
          status: QazaStatus.completed.name);

  Future<QazaRecord?> getOldestPending(
      {required String userId, String? prayerType}) async {
    final rows = await getPage(
        userId: userId,
        limit: 1,
        prayerType: prayerType,
        status: QazaStatus.pending.name);
    return rows.isEmpty ? null : rows.first;
  }


  Future<List<QazaRecord>> getByIds({
    required String userId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const <QazaRecord>[];
    final unique = ids.toSet().toList(growable: false);
    final result = <QazaRecord>[];
    for (var offset = 0; offset < unique.length; offset += 400) {
      final chunk = unique.skip(offset).take(400).toList(growable: false);
      final rows = await (select(qazaRecords)
            ..where((row) =>
                row.userId.equals(userId) & row.id.isIn(chunk)))
          .get();
      result.addAll(rows.map(_toDomain));
    }
    return result;
  }

  Future<int> softDeleteByIds({
    required String userId,
    required List<String> ids,
    required DateTime deletedAt,
  }) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      var changed = 0;
      for (final id in ids.toSet()) {
        final row = await (select(qazaRecords)
              ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
            .getSingleOrNull();
        if (row == null || row.status == QazaStatus.deleted.name) continue;
        changed += await (update(qazaRecords)
              ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
            .write(QazaRecordsCompanion(
              status: Value(QazaStatus.deleted.name),
              updatedAt: Value(deletedAt),
            ));
      }
      return changed;
    });
  }

  /// Conditional mutation used by operation Undo/Remove. The WHERE clause
  /// re-checks the complete precondition so an intervening completion/edit
  /// cannot be overwritten by an older operation action.
  Future<List<QazaRecord>> softDeletePendingIfUnchangedByIds({
    required String userId,
    required List<String> ids,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) async {
    if (ids.isEmpty) return const <QazaRecord>[];

    final changed = <QazaRecord>[];
    for (final id in ids.toSet()) {
      final row = await (select(qazaRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.id.equals(id) &
                r.status.equals(QazaStatus.pending.name) &
                r.createdAt.equals(expectedCreatedAt) &
                r.updatedAt.equals(expectedCreatedAt)))
          .getSingleOrNull();
      if (row == null) continue;

      final count = await (update(qazaRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.id.equals(id) &
                r.status.equals(QazaStatus.pending.name) &
                r.createdAt.equals(expectedCreatedAt) &
                r.updatedAt.equals(expectedCreatedAt)))
          .write(QazaRecordsCompanion(
        status: Value(QazaStatus.deleted.name),
        updatedAt: Value(deletedAt),
      ));
      if (count > 0) {
        changed.add(_toDomain(row).copyWith(
          status: QazaStatus.deleted,
          updatedAt: deletedAt,
        ));
      }
    }
    return changed;
  }

  Future<int> restoreDeletedByIds({
    required String userId,
    required List<String> ids,
    required DateTime restoredAt,
  }) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      var changed = 0;
      for (final id in ids.toSet()) {
        final row = await (select(qazaRecords)
              ..where((r) =>
                  r.userId.equals(userId) &
                  r.id.equals(id) &
                  r.status.equals(QazaStatus.deleted.name)))
            .getSingleOrNull();
        if (row == null) continue;
        final restoredStatus = row.completedAt == null
            ? QazaStatus.pending.name
            : QazaStatus.completed.name;
        changed += await (update(qazaRecords)
              ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
            .write(QazaRecordsCompanion(
              status: Value(restoredStatus),
              updatedAt: Value(restoredAt),
            ));
      }
      return changed;
    });
  }

  Future<int> undoAddedOperation({
    required String userId,
    required DateTime expectedCreatedAt,
    required List<String> candidateIds,
  }) async {
    if (candidateIds.isEmpty) return 0;
    return transaction(() async {
      var removed = 0;
      for (final id in candidateIds.toSet()) {
        final row = await (select(qazaRecords)
              ..where((r) =>
                  r.userId.equals(userId) &
                  r.id.equals(id) &
                  r.status.equals(QazaStatus.pending.name)))
            .getSingleOrNull();
        if (row == null ||
            !row.createdAt.isAtSameMomentAs(expectedCreatedAt) ||
            !row.updatedAt.isAtSameMomentAs(expectedCreatedAt)) {
          continue;
        }
        removed += await (delete(qazaRecords)
              ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
            .go();
      }
      return removed;
    });
  }

  Future<QazaRecordsPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
    int limit = defaultPageSize,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    _validatePage(limit, 0);
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (matchLastAction) {
          predicates.add(row.updatedAt.equals(operationAt));
        } else {
          predicates.add(row.operationId.equals(operationId));
        }
        if (status != null) {
          predicates.add(row.status.equals(status.name));
        }
        if (beforeOriginalDate != null) {
          predicates.add(
              row.originalDate.isSmallerThanValue(beforeOriginalDate) |
                  (row.originalDate.equals(beforeOriginalDate) &
                      row.id.isSmallerThanValue(beforeId!)));
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
    final visible = hasMore ? rows.take(limit) : rows;
    return QazaRecordsPage(
      records: visible.map(_toDomain).toList(growable: false),
      hasMore: hasMore,
    );
  }

  /// Returns operation counts directly from SQLite so History never
  /// materializes an entire operation just to render its summary.
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) async {
    final countExpression = qazaRecords.id.count();
    final grouped = selectOnly(qazaRecords)
      ..addColumns([qazaRecords.status, countExpression])
      ..where(
        qazaRecords.userId.equals(userId) &
            qazaRecords.operationId.equals(operationId),
      )
      ..groupBy([qazaRecords.status]);
    final rows = await grouped.get();

    var pending = 0;
    var completed = 0;
    var deleted = 0;
    for (final row in rows) {
      final status = row.read(qazaRecords.status);
      final count = row.read(countExpression) ?? 0;
      switch (status) {
        case QazaStatus.pending.name:
          pending += count;
        case QazaStatus.completed.name:
          completed += count;
        case QazaStatus.deleted.name:
          deleted += count;
      }
    }

    final unchangedExpression = qazaRecords.id.count();
    final unchangedQuery = selectOnly(qazaRecords)
      ..addColumns([unchangedExpression])
      ..where(
        qazaRecords.userId.equals(userId) &
            qazaRecords.operationId.equals(operationId) &
            qazaRecords.status.equals(QazaStatus.pending.name) &
            qazaRecords.createdAt.equalsExp(qazaRecords.updatedAt),
      );
    final unchangedPending =
        (await unchangedQuery.getSingle()).read(unchangedExpression) ?? 0;

    return QazaOperationSummary(
      pending: pending,
      completed: completed,
      deleted: deleted,
      unchangedPending: unchangedPending,
    );
  }

  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = defaultPageSize,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) async {
    _validatePage(limit, 0);
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[
          row.userId.equals(userId),
          row.status.equals(QazaStatus.deleted.name),
        ];
        if (beforeDeletedAt != null) {
          predicates.add(
              row.updatedAt.isSmallerThanValue(beforeDeletedAt) |
                  (row.updatedAt.equals(beforeDeletedAt) &
                      row.id.isSmallerThanValue(beforeId!)));
        }
        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => OrderingTerm.desc(r.updatedAt),
        (r) => OrderingTerm.desc(r.id),
      ])
      ..limit(limit + 1);
    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visible = hasMore ? rows.take(limit) : rows;
    return QazaHistoryPage(
      records: visible.map(_toDomain).toList(growable: false),
      hasMore: hasMore,
    );
  }

  Future<int> purgeDeletedBefore({
    required String userId,
    required DateTime cutoff,
  }) =>
      (delete(qazaRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.status.equals(QazaStatus.deleted.name) &
                r.updatedAt.isSmallerThanValue(cutoff)))
          .go();

  Future<void> replaceUserRecords(
      {required String userId,
      required List<QazaRecordsCompanion> records}) async {
    for (final record in records) {
      if (record.userId.value != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    await (delete(qazaRecords)..where((r) => r.userId.equals(userId))).go();
    for (final record in records) {
      await into(qazaRecords).insert(record);
    }
  }

  /// Deletes every row owned by [userId] and returns how many were removed.
  ///
  /// Rows belonging to other users are left untouched: the whole statement is
  /// scoped by the userId predicate.
  Future<int> deleteAllForUser({required String userId}) =>
      (delete(qazaRecords)..where((r) => r.userId.equals(userId))).go();

  /// Marks the given ids completed, returning the ids actually changed.
  ///
  /// One statement per id inside a single transaction, scoped by userId and
  /// by pending status, so a record already completed keeps its original
  /// timestamp and no other row in the ledger is touched.
  Future<List<String>> completeByIds({
    required String userId,
    required List<String> ids,
    required DateTime completedAt,
  }) async {
    if (ids.isEmpty) return const <String>[];
    return transaction(() async {
      final changed = <String>[];
      for (final id in ids) {
        final current = await (select(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(id)))
            .getSingleOrNull();
        if (current == null) continue;
        final existingCompletedAt = current.completedAt;
        if (current.status == QazaStatus.completed &&
            existingCompletedAt != null &&
            !completedAt.isBefore(existingCompletedAt)) {
          continue;
        }

        final updated = await (update(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(id)))
            .write(QazaRecordsCompanion(
          status: Value(QazaStatus.completed.name),
          completedAt: Value(completedAt),
          updatedAt: Value(completedAt),
        ));
        if (updated > 0) changed.add(id);
      }
      return changed;
    });
  }

  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletedAt.isEmpty) return const <QazaRecord>[];

    return transaction(() async {
      final changed = <QazaRecord>[];
      for (final entry in expectedCompletedAt.entries) {
        final current = await (select(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(entry.key)))
            .getSingleOrNull();
        if (current == null ||
            current.status != QazaStatus.completed.name ||
            current.completedAt == null ||
            !current.completedAt!.isAtSameMomentAs(entry.value) ||
            !current.updatedAt.isAtSameMomentAs(entry.value)) {
          continue;
        }

        final updated = await (update(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(entry.key)))
            .write(QazaRecordsCompanion(
          status: Value(QazaStatus.pending.name),
          completedAt: Value(null),
          updatedAt: Value(undoneAt),
        ));
        if (updated > 0) {
          changed.add(QazaRecord(
            id: current.id,
            userId: current.userId,
            operationId: current.operationId,
            prayerType: PrayerType.values.firstWhere(
              (value) => value.name == current.prayerType,
            ),
            originalDate: current.originalDate,
            status: QazaStatus.pending,
            completedAt: null,
            createdAt: current.createdAt,
            updatedAt: undoneAt,
          ));
        }
      }
      return changed;
    });
  }

  Future<int> count(
      {required String userId, String? prayerType, String? status}) async {
    final query = selectOnly(qazaRecords)
      ..addColumns([qazaRecords.id.count()])
      ..where(qazaRecords.userId.equals(userId));
    if (prayerType != null) {
      query.where(qazaRecords.prayerType.equals(prayerType));
    }
    if (status != null) {
      query.where(qazaRecords.status.equals(status));
    } else {
      query.where(qazaRecords.status.isNotIn([QazaStatus.deleted.name]));
    }
    return (await query.getSingle()).read(qazaRecords.id.count()) ?? 0;
  }

  Future<int> insertRecord(QazaRecordsCompanion record) =>
      into(qazaRecords).insert(record, mode: InsertMode.insertOrIgnore);

  Future<void> upsertRecords(List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return;
    await transaction(() async {
      for (final record in records) {
        await into(qazaRecords).insertOnConflictUpdate(record);
      }
    });
  }

  /// Inserts records atomically. Each row is still constrained by its own
  /// userId in SQLite; callers that need a single-user transaction should use
  /// replaceUserRecords, which validates the namespace before replacing it.
  Future<int> insertRecords(List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return 0;
    return transaction(() async {
      var inserted = 0;
      for (final record in records) {
        final result = await into(qazaRecords)
            .insert(record, mode: InsertMode.insertOrIgnore);
        if (result > 0) inserted++;
      }
      return inserted;
    });
  }

  Future<bool> updateRecord(QazaRecord record) =>
      update(qazaRecords).replace(_toCompanion(record));
  Future<int> deleteById({required String userId, required String id}) =>
      (delete(qazaRecords)
            ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
          .go();

  QazaRecord _toDomain(QazaRecordRow row) => QazaRecord(
        id: row.id,
        userId: row.userId,
        operationId: row.operationId,
        prayerType: PrayerType.values.firstWhere(
            (value) => value.name == row.prayerType,
            orElse: () => throw StateError(
                'Unknown prayer type "${row.prayerType}" in local database.')),
        originalDate: row.originalDate,
        status: QazaStatus.values.firstWhere(
            (value) => value.name == row.status,
            orElse: () => throw StateError(
                'Unknown Qaza status "${row.status}" in local database.')),
        completedAt: row.completedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  QazaRecordsCompanion _toCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
          id: record.id,
          userId: record.userId,
          operationId: Value(record.operationId),
          prayerType: record.prayerType.name,
          originalDate: record.originalDate,
          status: record.status.name,
          completedAt: record.completedAt == null
              ? const Value.absent()
              : Value(record.completedAt),
          createdAt: record.createdAt,
          updatedAt: record.updatedAt);
  void _validatePage(int limit, int offset) {
    if (limit < 1 || limit > maxPageSize) {
      throw ArgumentError.value(limit, 'limit');
    }
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
  }

  void _validateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
  }
}