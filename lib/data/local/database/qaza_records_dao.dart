import 'package:drift/drift.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../core/utils/qaza_completion_id.dart';
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

  Future<List<QazaRecord>> getByAdditionId({
    required String userId,
    required String additionId,
  }) async {
    final rows = await (select(qazaRecords)
          ..where(
            (row) => row.userId.equals(userId) & row.additionId.equals(additionId),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.originalDate),
            (row) => OrderingTerm.asc(row.id),
          ]))
        .get();
    return rows.map(_toDomain).toList(growable: false);
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

  Future<QazaRecordsPage> getKeysetPage({
    required String userId,
    int limit = defaultPageSize,
    String? prayerType,
    Iterable<String>? prayerTypes,
    String? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? toExclusive,
    DateTime? afterOriginalDate,
    String? afterId,
    DateTime? beforeOriginalDate,
    String? beforeId,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    _validatePage(limit, 0);
    final completedMode = status == QazaStatus.completed.name;
    if (to != null && toExclusive != null) {
      throw ArgumentError('Provide either to or toExclusive, not both.');
    }
    if (completedMode && to != null) {
      throw ArgumentError('Completed pages require toExclusive.');
    }
    if (!completedMode && toExclusive != null) {
      throw ArgumentError('toExclusive is only valid for Completed pages.');
    }
    _validateRange(from, to);
    if (toExclusive != null && (from == null || !from.isBefore(toExclusive))) {
      throw ArgumentError('from must be before toExclusive');
    }
    if (completedMode) {
      if ((afterCompletedAt == null) != (afterId == null) ||
          (beforeCompletedAt == null) != (beforeId == null) ||
          (afterCompletedAt != null && beforeCompletedAt != null) ||
          afterOriginalDate != null ||
          beforeOriginalDate != null) {
        throw ArgumentError('Invalid completed pagination cursor');
      }
    } else {
      if ((afterOriginalDate == null) != (afterId == null) ||
          (beforeOriginalDate == null) != (beforeId == null) ||
          afterCompletedAt != null ||
          beforeCompletedAt != null ||
          (afterOriginalDate != null && beforeOriginalDate != null)) {
        throw ArgumentError('Invalid pending pagination cursor');
      }
    }

    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (prayerTypes != null) {
          predicates.add(row.prayerType.isIn(prayerTypes));
        }
        if (status != null) {
          predicates.add(row.status.equals(status));
        }
        if (additionId != null) {
          predicates.add(row.additionId.equals(additionId));
        }
        if (completedMode) {
          predicates.add(row.completedAt.isNotNull());
          if (from != null) {
            predicates.add(row.completedAt.isBiggerOrEqualValue(from));
          }
          if (toExclusive != null) {
            predicates.add(row.completedAt.isSmallerThanValue(toExclusive));
          }
        } else {
          if (from != null) {
            predicates.add(row.originalDate.isBiggerOrEqualValue(from));
          }
          if (to != null) {
            predicates.add(row.originalDate.isSmallerOrEqualValue(to));
          }
        }

        if (completedMode) {
          if (afterCompletedAt != null) {
            predicates.add(
              row.completedAt.isSmallerThanValue(afterCompletedAt) |
                  (row.completedAt.equals(afterCompletedAt) &
                      row.id.isSmallerThanValue(afterId!)),
            );
          } else if (beforeCompletedAt != null) {
            predicates.add(
              row.completedAt.isSmallerThanValue(beforeCompletedAt) |
                  (row.completedAt.equals(beforeCompletedAt) &
                      row.id.isSmallerThanValue(beforeId!)),
            );
          }
        } else if (afterOriginalDate != null) {
          predicates.add(
            row.originalDate.isBiggerThanValue(afterOriginalDate) |
                (row.originalDate.equals(afterOriginalDate) &
                    row.id.isBiggerThanValue(afterId!)),
          );
        } else if (beforeOriginalDate != null) {
          predicates.add(
            row.originalDate.isSmallerThanValue(beforeOriginalDate) |
                (row.originalDate.equals(beforeOriginalDate) &
                    row.id.isSmallerThanValue(beforeId!)),
          );
        }

        return predicates.reduce((a, b) => a & b);
      })
      ..orderBy([
        (r) => completedMode
            ? OrderingTerm.desc(r.completedAt)
            : (descending
                ? OrderingTerm.desc(r.originalDate)
                : OrderingTerm.asc(r.originalDate)),
        (r) => completedMode
            ? OrderingTerm.desc(r.id)
            : (descending
                ? OrderingTerm.desc(r.id)
                : OrderingTerm.asc(r.id)),
      ])
      ..limit(limit + 1);

    final rows = await query.get();
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    return QazaRecordsPage(
      records: visibleRows.map(_toDomain).toList(growable: false),
      hasMore: hasMore,
    );
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
      DateTime? to,
      DateTime? toExclusive}) async {
    _validatePage(limit, offset);
    final completedMode = status == QazaStatus.completed.name;
    if (completedMode && to != null) {
      throw ArgumentError('Completed pages require toExclusive.');
    }
    if (!completedMode && toExclusive != null) {
      throw ArgumentError('toExclusive is only valid for Completed pages.');
    }
    _validateRange(from, to);
    if (toExclusive != null && (from == null || !from.isBefore(toExclusive))) {
      throw ArgumentError('from must be before toExclusive');
    }
    final query = select(qazaRecords)
      ..where((row) {
        final predicates = <Expression<bool>>[row.userId.equals(userId)];
        if (prayerType != null) {
          predicates.add(row.prayerType.equals(prayerType));
        }
        if (status != null) {
          predicates.add(row.status.equals(status));
        }
        if (completedMode) {
          predicates.add(row.completedAt.isNotNull());
          if (from != null) {
            predicates.add(row.completedAt.isBiggerOrEqualValue(from));
          }
          if (toExclusive != null) {
            predicates.add(row.completedAt.isSmallerThanValue(toExclusive));
          }
        } else {
          if (from != null) {
            predicates.add(row.originalDate.isBiggerOrEqualValue(from));
          }
          if (to != null) {
            predicates.add(row.originalDate.isSmallerOrEqualValue(to));
          }
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
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<String>? prayerTypes,
  }) async {
    if (!from.isBefore(toExclusive)) {
      throw ArgumentError('from must be before toExclusive');
    }
    if (prayerTypes != null && prayerTypes.isEmpty) {
      return const <QazaActivityRow>[];
    }

    final query = selectOnly(qazaRecords)
      ..addColumns([qazaRecords.completedAt, qazaRecords.prayerType])
      ..where(
        qazaRecords.userId.equals(userId) &
            qazaRecords.status.equals(QazaStatus.completed.name) &
            qazaRecords.completedAt.isBiggerOrEqualValue(from) &
            qazaRecords.completedAt.isSmallerThanValue(toExclusive) &
            (prayerTypes == null
                ? const Constant(true)
                : qazaRecords.prayerType.isIn(prayerTypes)),
      )
      ..orderBy([
        OrderingTerm.asc(qazaRecords.completedAt),
        OrderingTerm.asc(qazaRecords.id),
      ]);

    final rows = await query.get();
    return rows.map((row) {
      final completedAt = row.read(qazaRecords.completedAt);
      final prayerName = row.read(qazaRecords.prayerType);
      if (completedAt == null || prayerName == null) {
        throw StateError('Completed Qaza activity row is missing required data.');
      }
      final prayerType = PrayerType.values.firstWhere(
        (value) => value.name == prayerName,
        orElse: () => throw StateError(
          'Unknown prayer type "$prayerName" in local database.',
        ),
      );
      return QazaActivityRow(
        completedAt: completedAt,
        prayerType: prayerType,
      );
    }).toList(growable: false);
  }

  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<String>? prayerTypes,
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
            qazaRecords.completedAt.isSmallerThanValue(to) &
            (prayerTypes == null
                ? const Constant(true)
                : qazaRecords.prayerType.isIn(prayerTypes)),
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
            row.originalDate.equals(originalDate),
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
            ..where((row) => row.userId.equals(userId) & row.id.isIn(chunk)))
          .get();
      result.addAll(rows.map(_toDomain));
    }
    return result;
  }

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
  Future<List<QazaRecord>> completeByIds({
    required String userId,
    required List<String> ids,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) async {
    if (ids.isEmpty) return const <QazaRecord>[];

    return transaction(() async {
      final changed = <QazaRecord>[];
      for (final id in ids.toSet()) {
        final current = await (select(qazaRecords)
              ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
            .getSingleOrNull();
        if (current == null || current.status != QazaStatus.pending.name) {
          continue;
        }

        final marker = completionIds?[id] ?? newQazaCompletionId();
        if (marker.isEmpty) {
          throw StateError('A completion marker is required.');
        }

        final updated = await (update(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) &
                  row.id.equals(id) &
                  row.status.equals(QazaStatus.pending.name)))
            .write(QazaRecordsCompanion(
          status: Value(QazaStatus.completed.name),
          completedAt: Value(completedAt),
          completionId: Value(marker),
          recordVersion: Value(current.recordVersion + 1),
          updatedAt: Value(completedAt),
        ));

        if (updated > 0) {
          changed.add(
            QazaRecord(
              id: current.id,
              userId: current.userId,
              prayerType: PrayerType.values.firstWhere(
                (value) => value.name == current.prayerType,
              ),
              originalDate: current.originalDate,
              status: QazaStatus.completed,
              completedAt: completedAt,
              completionId: marker,
              additionId: current.additionId,
              recordVersion: current.recordVersion + 1,
              createdAt: current.createdAt,
              updatedAt: completedAt,
            ),
          );
        }
      }
      return List.unmodifiable(changed);
    });
  }

  /// Marks completed records as pending only when the selected
  /// completion marker still matches the current row. The transition and
  /// version increment happen atomically inside one transaction.
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) async {
    if (expectedCompletionIds.isEmpty) return const <QazaRecord>[];

    return transaction(() async {
      final changed = <QazaRecord>[];
      for (final entry in expectedCompletionIds.entries) {
        final current = await (select(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(entry.key)))
            .getSingleOrNull();
        if (current == null ||
            current.status != QazaStatus.completed.name ||
            current.completionId != entry.value) {
          continue;
        }

        final nextVersion = current.recordVersion + 1;
        final updated = await (update(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) &
                  row.id.equals(entry.key) &
                  row.status.equals(QazaStatus.completed.name) &
                  row.completionId.equals(entry.value)))
            .write(QazaRecordsCompanion(
          status: const Value(QazaStatus.pending.name),
          completedAt: const Value(null),
          completionId: const Value(null),
          recordVersion: Value(nextVersion),
          updatedAt: Value(updatedAt),
        ));

        if (updated > 0) {
          changed.add(
            QazaRecord(
              id: current.id,
              userId: current.userId,
              prayerType: PrayerType.values.firstWhere(
                (value) => value.name == current.prayerType,
              ),
              originalDate: current.originalDate,
              status: QazaStatus.pending,
              completedAt: null,
              completionId: null,
              additionId: current.additionId,
              recordVersion: nextVersion,
              createdAt: current.createdAt,
              updatedAt: updatedAt,
            ),
          );
        }
      }
      return List.unmodifiable(changed);
    });
  }

  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletionIds.isEmpty) return const <QazaRecord>[];

    return transaction(() async {
      final changed = <QazaRecord>[];
      for (final entry in expectedCompletionIds.entries) {
        final current = await (select(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(entry.key)))
            .getSingleOrNull();
        if (current == null ||
            current.status != QazaStatus.completed.name ||
            current.completionId != entry.value) {
          continue;
        }

        final updated = await (update(qazaRecords)
              ..where((row) =>
                  row.userId.equals(userId) & row.id.equals(entry.key)))
            .write(QazaRecordsCompanion(
          status: Value(QazaStatus.pending.name),
          completedAt: const Value(null),
          completionId: const Value(null),
          recordVersion: Value(current.recordVersion + 1),
          updatedAt: Value(undoneAt),
        ));
        if (updated > 0) {
          changed.add(QazaRecord(
            id: current.id,
            userId: current.userId,
            prayerType: PrayerType.values.firstWhere(
              (value) => value.name == current.prayerType,
            ),
            originalDate: current.originalDate,
            status: QazaStatus.pending,
            completedAt: null,
            completionId: null,
            additionId: current.additionId,
            recordVersion: current.recordVersion + 1,
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
      // A deleted state no longer exists; a null status counts all live rows.
    }
    return (await query.getSingle()).read(qazaRecords.id.count()) ?? 0;
  }

  Future<bool> _insertIfAbsent(QazaRecordsCompanion record) async {
    final existing = await (select(qazaRecords)
          ..where(
            (row) =>
                row.id.equals(record.id.value) |
                (row.userId.equals(record.userId.value) &
                    row.prayerType.equals(record.prayerType.value) &
                    row.originalDate.equals(record.originalDate.value)),
          )
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return false;

    await into(qazaRecords).insert(record);
    return true;
  }

  Future<int> insertRecord(QazaRecordsCompanion record) async =>
      (await _insertIfAbsent(record)) ? 1 : 0;

  Future<void> upsertRecords(List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return;
    await transaction(() async {
      for (final record in records) {
        await into(qazaRecords).insertOnConflictUpdate(record);
      }
    });
  }

  /// Inserts records atomically and reports ids actually accepted by SQLite.
  /// Both primary-key and user/prayer/date uniqueness conflicts are ignored.
  /// Inserts rows using the caller's transaction. The Drift local-store
  /// bulk path wraps this together with its outbox write in one transaction.
  Future<List<String>> insertRecordsReturningInsertedIds(
      List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return const <String>[];
    final insertedIds = <String>[];
    for (final record in records) {
      if (await _insertIfAbsent(record)) {
        insertedIds.add(record.id.value);
      }
    }
    return insertedIds;
  }

  /// Inserts records atomically. Each row is still constrained by its own
  /// userId in SQLite; callers that need a single-user transaction should use
  /// replaceUserRecords, which validates the namespace before replacing it.
  Future<int> insertRecords(List<QazaRecordsCompanion> records) async {
    if (records.isEmpty) return 0;
    return transaction(() async {
      var inserted = 0;
      for (final record in records) {
        if (await _insertIfAbsent(record)) inserted++;
      }
      return inserted;
    });
  }

  Future<bool> updateRecord(QazaRecord record) async {
    final updated = await (update(qazaRecords)
          ..where(
            (row) =>
                row.userId.equals(record.userId) &
                row.id.equals(record.id) &
                row.recordVersion.equals(record.recordVersion),
          ))
        .write(
      _toCompanion(
        record.copyWith(
          recordVersion: record.recordVersion + 1,
        ),
      ),
    );
    return updated > 0;
  }
  Future<int> deleteById({required String userId, required String id}) =>
      (delete(qazaRecords)
            ..where((r) => r.userId.equals(userId) & r.id.equals(id)))
          .go();

  QazaRecord _toDomain(QazaRecordRow row) => QazaRecord(
        id: row.id,
        userId: row.userId,
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
        completionId: row.completionId,
        additionId: row.additionId,
        recordVersion: row.recordVersion,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  QazaRecordsCompanion _toCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
          id: record.id,
          userId: record.userId,
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
