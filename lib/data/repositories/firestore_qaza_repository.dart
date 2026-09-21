import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/qaza_sync_remote_data_source.dart';

class FirestoreQazaRepository
    implements QazaRepository, QazaSyncRemoteDataSource {
  FirestoreQazaRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Leaves headroom for the change-log document in every atomic write.
  static const int maxBatchSize = 400;
  static const int _deleteBatchSize = 400;

  CollectionReference<Map<String, dynamic>> _recordsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('qazaRecords');

  CollectionReference<Map<String, dynamic>> _changesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('qazaChanges');

  DocumentReference<Map<String, dynamic>> _syncStateDocument(String userId) =>
      _firestore.collection('users').doc(userId).collection('syncMetadata').doc('state');

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null) {
      query = query.where('prayerType', isEqualTo: prayerType.name);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    final records = (await query.get()).docs.map(_fromDocument).toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
  }

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }

    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null) {
      query = query.where('prayerType', isEqualTo: prayerType.name);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    if (from != null) {
      query = query.where('originalDate',
          isGreaterThanOrEqualTo: QazaDate.key(QazaDate.normalize(from)));
    }
    if (to != null) {
      query = query.where('originalDate',
          isLessThanOrEqualTo: QazaDate.key(QazaDate.normalize(to)));
    }
    query = query.orderBy('originalDate').orderBy(FieldPath.documentId);
    if (afterOriginalDate != null) {
      query = query.startAfter(
          [QazaDate.key(QazaDate.normalize(afterOriginalDate)), afterId]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.take(limit) : snapshot.docs;
    return QazaPage(
      records: docs.map(_fromDocument).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final page = await getPage(
      userId: userId,
      limit: 1,
      prayerType: prayerType,
      status: QazaStatus.pending,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('from must be <= to');
    }
    if ((beforeOriginalDate == null) != (beforeId == null)) {
      throw ArgumentError(
          'beforeOriginalDate and beforeId must be provided together');
    }

    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null) {
      query = query.where('prayerType', isEqualTo: prayerType.name);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    if (from != null) {
      query = query.where('originalDate',
          isGreaterThanOrEqualTo: QazaDate.key(QazaDate.normalize(from)));
    }
    if (to != null) {
      query = query.where('originalDate',
          isLessThanOrEqualTo: QazaDate.key(QazaDate.normalize(to)));
    }
    query = query
        .orderBy('originalDate', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (beforeOriginalDate != null) {
      query = query.startAfter(
          [QazaDate.key(QazaDate.normalize(beforeOriginalDate)), beforeId]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.take(limit) : snapshot.docs;
    return QazaHistoryPage(
      records: docs.map(_fromDocument).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
          {required String userId}) async =>
      QazaProgressSummary.fromRecords(await getRecords(userId: userId));

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) {
      throw ArgumentError('from must be before to');
    }
    final snapshot = await _recordsCollection(userId)
        .where('status', isEqualTo: QazaStatus.completed.name)
        .where('completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('completedAt', isLessThan: Timestamp.fromDate(to))
        .get();
    return snapshot.size;
  }

  @override
  Future<void> addRecord(QazaRecord record) async => addRecords([record]);

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;

    for (var start = 0; start < records.length; start += maxBatchSize) {
      final end = start + maxBatchSize < records.length
          ? start + maxBatchSize
          : records.length;
      final operations = <PendingSyncOp>[
        for (final record in records.sublist(start, end))
          PendingSyncOp(
            id: 'add_${record.id}',
            type: SyncOpType.add,
            userId: record.userId,
            queuedAt: record.createdAt,
            record: record,
          ),
      ];
      await applyOperationsBatch(
        userId: operations.first.userId,
        operations: operations,
      );
    }
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final reference = _recordsCollection(userId).doc(recordId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final record = _fromDocument(snapshot);
      if (record.userId != userId || record.status == QazaStatus.completed) {
        return;
      }
      final completed = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );
      transaction.set(
        reference,
        _toMap(completed, serverUpdatedAt: true),
        SetOptions(merge: false),
      );
    });
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    for (final recordId in recordIds.toSet()) {
      await completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );
    }
  }

  @override
  Future<void> updateRecord({required QazaRecord record}) async {
    await applyOperationsBatch(
      userId: record.userId,
      operations: [
        PendingSyncOp(
          id: 'update_direct_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
          type: SyncOpType.update,
          userId: record.userId,
          queuedAt: record.updatedAt,
          record: record,
          targetRecordId: record.id,
        ),
      ],
    );
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    final snapshot = await _recordsCollection(userId).doc(recordId).get();
    if (!snapshot.exists) return;
    final record = _fromDocument(snapshot);
    await applyOperationsBatch(
      userId: userId,
      operations: [
        PendingSyncOp(
          id: 'delete_direct_${recordId}_${DateTime.now().microsecondsSinceEpoch}',
          type: SyncOpType.delete,
          userId: userId,
          queuedAt: DateTime.now(),
          targetRecordId: recordId,
          record: record,
        ),
      ],
    );
  }

  @override
  Future<void> resetUserRecords({
    required String userId,
    String? operationId,
  }) async {
    await resetUserRecordsWithOperation(
      userId: userId,
      operationId: operationId ?? 'reset_${userId}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) => resetUserRecordsWithOperation(
        userId: userId,
        operationId: operationId,
      );

  @override
  Future<void> deleteCloudData({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }

    // Delete only the authenticated user's cloud collections. The local
    // offline ledger is owned by OfflineFirstQazaRepository and is untouched.
    await _deleteCollection(_recordsCollection(userId));
    await _deleteCollection(_changesCollection(userId));
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> collection) async {
    while (true) {
      final snapshot = await collection.limit(_deleteBatchSize).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<QazaRemoteResetState> getResetState(
      {required String userId}) async {
    final snapshot = await _syncStateDocument(userId).get();
    final data = snapshot.data();
    if (data == null) {
      return const QazaRemoteResetState(generation: 0, inProgress: false);
    }
    return QazaRemoteResetState(
      generation: (data['generation'] as num?)?.toInt() ?? 0,
      inProgress: data['resetInProgress'] as bool? ?? false,
    );
  }

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  }) async {
    final snapshot = await _changesCollection(userId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _cursorFromChange(snapshot.docs.single);
  }

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > maxBatchSize) {
      throw ArgumentError.value(limit, 'limit');
    }

    Query<Map<String, dynamic>> query = _changesCollection(userId)
        .orderBy('createdAt')
        .orderBy(FieldPath.documentId);
    if (after != null) {
      query = query.startAfter([
        Timestamp.fromDate(after.at),
        after.id,
      ]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.take(limit) : snapshot.docs;
    return QazaRemoteChangePage(
      changes: docs.map(_changeFromDocument).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    if (operations.isEmpty) {
      throw ArgumentError('operations must not be empty');
    }
    if (operations.length > maxBatchSize) {
      throw ArgumentError.value(
          operations.length, 'operations', 'Batch is too large');
    }

    final type = operations.first.type;
    if (type == SyncOpType.reset) {
      throw ArgumentError('Reset must use resetUserRecordsForSync.');
    }
    if (operations.any((op) => op.type != type || op.userId != userId)) {
      throw ArgumentError(
          'All operations in a batch must share userId and type.');
    }

    if (type == SyncOpType.update || type == SyncOpType.delete) {
      return _applyUpdateDeleteBatch(
        userId: userId,
        operations: operations,
      );
    }

    final reset = await getResetState(userId: userId);
    if (reset.inProgress) {
      throw StateError('Remote reset is currently in progress.');
    }

    final changeId = 'change_batch_${_stableBatchHash(operations)}';
    final changeReference = _changesCollection(userId).doc(changeId);
    final batch = _firestore.batch();
    final records = <QazaRecord>[];

    batch.set(
      _syncStateDocument(userId),
      {
        'generation': reset.generation,
        'resetInProgress': false,
      },
      SetOptions(merge: true),
    );

    for (final operation in operations) {
      final record = operation.record;
      if (record == null ||
          record.userId != userId ||
          record.id.isEmpty ||
          !_isOwned(userId, record.userId)) {
        throw StateError('Sync operation contains an invalid record.');
      }

      records.add(record);
      batch.set(
        _recordsCollection(userId).doc(record.id),
        _toMap(
          record,
          serverUpdatedAt: true,
          syncGeneration: reset.generation,
        ),
        SetOptions(merge: false),
      );
    }

    batch.set(changeReference, {
      'changeType': type == SyncOpType.add ? 'upsert' : 'complete',
      'generation': reset.generation,
      'createdAt': FieldValue.serverTimestamp(),
      'records': [
        for (final record in records)
          _toMap(record, syncGeneration: reset.generation),
      ],
      'recordIds': const <String>[],
    });

    await batch.commit();
    final committed = await changeReference.get();
    return _cursorFromChange(committed);
  }

  Future<QazaRemoteChangeCursor> _applyUpdateDeleteBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    final type = operations.first.type;
    final latestById = <String, PendingSyncOp>{};
    for (final operation in operations) {
      final id = operation.targetRecordId ?? operation.record?.id;
      if (id == null || id.isEmpty) {
        throw StateError('Sync operation is missing its target record id.');
      }
      final previous = latestById[id];
      if (previous == null ||
          operation.queuedAt.isAfter(previous.queuedAt) ||
          (operation.queuedAt.isAtSameMomentAs(previous.queuedAt) &&
              operation.id.compareTo(previous.id) > 0)) {
        latestById[id] = operation;
      }
    }

    final reset = await getResetState(userId: userId);
    if (reset.inProgress) {
      throw StateError('Remote reset is currently in progress.');
    }

    final changeId = 'change_batch_${_stableBatchHash(latestById.values.toList(growable: false))}';
    final changeReference = _changesCollection(userId).doc(changeId);
    final accepted = <QazaRecord>[];
    final deletedIds = <String>[];
    final rejected = <QazaRecord>[];

    await _firestore.runTransaction((transaction) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in latestById.keys) {
        snapshots[id] = await transaction.get(_recordsCollection(userId).doc(id));
      }

      transaction.set(
        _syncStateDocument(userId),
        {
          'generation': reset.generation,
          'resetInProgress': false,
        },
        SetOptions(merge: true),
      );

      for (final operation in latestById.values) {
        final id = operation.targetRecordId ?? operation.record?.id;
        if (id == null) continue;
        final snapshot = snapshots[id]!;
        if (operation.type == SyncOpType.update) {
          final record = operation.record;
          if (record == null ||
              record.userId != userId ||
              record.id != id ||
              !_isOwned(userId, record.userId)) {
            throw StateError('Sync update contains an invalid record.');
          }
          final current = snapshot.exists ? _fromDocument(snapshot) : null;
          if (current != null &&
              current.updatedAt.isAfter(record.updatedAt)) {
            rejected.add(current);
            continue;
          }
          accepted.add(record);
          transaction.set(
            _recordsCollection(userId).doc(id),
            _toMap(
              record,
              serverUpdatedAt: true,
              syncGeneration: reset.generation,
            ),
            SetOptions(merge: false),
          );
        } else {
          final current = snapshot.exists ? _fromDocument(snapshot) : null;
          if (current != null) {
            final tombstone = operation.record;
            if (tombstone != null &&
                current.updatedAt.isAfter(tombstone.updatedAt)) {
              rejected.add(current);
              continue;
            }
            transaction.delete(_recordsCollection(userId).doc(id));
          }
          deletedIds.add(id);
        }
      }

      transaction.set(
        changeReference,
        {
          'changeType': type == SyncOpType.update ? 'update' : 'delete',
          'generation': reset.generation,
          'createdAt': FieldValue.serverTimestamp(),
          'records': [
            for (final record in [...accepted, ...rejected])
              _toMap(record, syncGeneration: reset.generation),
          ],
          'recordIds': type == SyncOpType.delete
              ? deletedIds
              : const <String>[],
        },
      );
    });

    final committed = await changeReference.get();
    return _cursorFromChange(committed);
  }

  Future<QazaRemoteChangeCursor> resetUserRecordsWithOperation({
    required String userId,
    required String operationId,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }

    final stateReference = _syncStateDocument(userId);
    var generation = 0;
    var effectiveOperationId = operationId;
    var alreadyCompleted = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(stateReference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final inProgress = data['resetInProgress'] as bool? ?? false;
      final existingOperation = data['resetOperationId'] as String?;
      final completedOperation =
          data['lastCompletedResetOperationId'] as String?;

      if (completedOperation == operationId && !inProgress) {
        generation = (data['generation'] as num?)?.toInt() ?? 0;
        alreadyCompleted = true;
        return;
      }

      generation = (data['generation'] as num?)?.toInt() ?? 0;
      if (inProgress) {
        effectiveOperationId = existingOperation ?? operationId;
      } else {
        generation += 1;
        effectiveOperationId = operationId;
      }

      transaction.set(
        stateReference,
        {
          'generation': generation,
          'resetInProgress': true,
          'resetOperationId': effectiveOperationId,
          'lastCompletedResetOperationId': completedOperation,
        },
        SetOptions(merge: true),
      );
    });

    if (alreadyCompleted) {
      final changeReference =
          _changesCollection(userId).doc('reset_$operationId');
      final committed = await changeReference.get();
      if (!committed.exists) {
        throw StateError(
            'Completed reset $operationId has no reset change event.');
      }
      return _cursorFromChange(committed);
    }

    final collection = _recordsCollection(userId);
    while (true) {
      final snapshot = await collection.limit(_deleteBatchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }

    final changeId = 'reset_$effectiveOperationId';
    final changeReference = _changesCollection(userId).doc(changeId);
    final finalBatch = _firestore.batch();

    finalBatch.set(changeReference, {
      'changeType': 'reset',
      'generation': generation,
      'createdAt': FieldValue.serverTimestamp(),
      'records': const <Map<String, dynamic>>[],
    });

    finalBatch.set(
      stateReference,
      {
        'generation': generation,
        'resetInProgress': false,
        'resetOperationId': null,
        'lastCompletedResetOperationId': effectiveOperationId,
      },
      SetOptions(merge: true),
    );

    await finalBatch.commit();
    final committed = await changeReference.get();
    return _cursorFromChange(committed);
  }

  QazaRemoteChange _changeFromDocument(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError(
          'Qaza sync change ${document.id} has no data.');
    }

    final createdAt = _timestamp(data['createdAt'], 'createdAt');
    final generation = (data['generation'] as num?)?.toInt() ?? 0;
    final typeName = data['changeType'] as String? ?? 'upsert';
    final type = switch (typeName) {
      'update' => QazaRemoteChangeType.update,
      'complete' => QazaRemoteChangeType.complete,
      'delete' => QazaRemoteChangeType.delete,
      'reset' => QazaRemoteChangeType.reset,
      _ => QazaRemoteChangeType.upsert,
    };

    final rawRecords = data['records'];
    final records = <QazaRecord>[];
    if (rawRecords is Iterable) {
      for (final raw in rawRecords) {
        if (raw is Map) {
          records.add(_fromMap(raw, document.id));
        }
      }
    }
    final rawRecordIds = data['recordIds'];
    final recordIds = rawRecordIds is Iterable
        ? rawRecordIds.whereType<String>().toList(growable: false)
        : const <String>[];

    return QazaRemoteChange(
      type: type,
      cursor: QazaRemoteChangeCursor(
        at: createdAt,
        id: document.id,
        generation: generation,
      ),
      records: List.unmodifiable(records),
      recordIds: recordIds,
    );
  }

  QazaRemoteChangeCursor _cursorFromChange(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError(
          'Qaza sync change ${document.id} has no data.');
    }
    return QazaRemoteChangeCursor(
      at: _timestamp(data['createdAt'], 'createdAt'),
      id: document.id,
      generation: (data['generation'] as num?)?.toInt() ?? 0,
    );
  }

  String _stableBatchHash(List<PendingSyncOp> operations) {
    var hash = 0xcbf29ce484222325;
    for (final operation in operations) {
      for (final unit in operation.id.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      }
      hash ^= 0xff;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Map<String, dynamic> _toMap(
    QazaRecord record, {
    bool serverUpdatedAt = false,
    int? syncGeneration,
  }) {
    return {
      'id': record.id,
      'userId': record.userId,
      'prayerType': record.prayerType.name,
      'originalDate': QazaDate.key(record.originalDate),
      'status': record.status.name,
      'completedAt': record.completedAt == null
          ? null
          : Timestamp.fromDate(record.completedAt!),
      'createdAt': Timestamp.fromDate(record.createdAt),
      'updatedAt': serverUpdatedAt
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(record.updatedAt),
      if (syncGeneration != null) 'syncGeneration': syncGeneration,
    };
  }

  QazaRecord _fromMap(Map raw, String id) {
    final prayerName = raw['prayerType'] as String?;
    final statusName = raw['status'] as String?;
    final prayerType = PrayerType.values.firstWhere(
      (value) => value.name == prayerName,
      orElse: () => throw StateError('Unknown prayer type in change $id.'),
    );
    final status = QazaStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => throw StateError('Unknown status in change $id.'),
    );

    return QazaRecord(
      id: raw['id'] as String? ?? id,
      userId: raw['userId'] as String? ?? '',
      prayerType: prayerType,
      originalDate: _originalDate(raw['originalDate'], id),
      status: status,
      completedAt: _nullableTimestamp(raw['completedAt']),
      createdAt: _timestamp(raw['createdAt'], 'createdAt'),
      updatedAt: _timestamp(raw['updatedAt'], 'updatedAt'),
    );
  }

  QazaRecord _fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError(
          'Qaza record ${document.id} has no data.');
    }
    return _fromMap({...data, 'id': document.id}, document.id);
  }

  DateTime _originalDate(Object? value, String id) {
    if (value is String) return QazaDate.parseKey(value);
    if (value is Timestamp) return QazaDate.fromRecordId(id);
    throw StateError(
        'Missing or invalid originalDate in Firestore Qaza record.');
  }

  DateTime _timestamp(Object? value, String field) {
    if (value is Timestamp) return value.toDate();
    throw StateError(
        'Missing or invalid $field in Firestore Qaza record.');
  }

  DateTime? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw StateError('Invalid completedAt in Firestore Qaza record.');
  }

  bool _isOwned(String userId, String recordUserId) =>
      userId.isNotEmpty && userId == recordUserId;
}
