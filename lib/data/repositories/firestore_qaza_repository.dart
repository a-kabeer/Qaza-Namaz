import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';

class FirestoreQazaRepository implements QazaRepository {
  FirestoreQazaRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _recordsCollection(
    String userId,
  ) {
    return _firestore.collection('users').doc(userId).collection('qazaRecords');
  }

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

    final snapshot = await query.get();
    final records = snapshot.docs
        .map((document) => _fromDocument(document))
        .toList();

    records.sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
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
      throw ArgumentError('beforeOriginalDate and beforeId must be provided together');
    }

    Query<Map<String, dynamic>> query = _recordsCollection(userId);

    if (prayerType != null) {
      query = query.where('prayerType', isEqualTo: prayerType.name);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    if (from != null) {
      query = query.where(
        'originalDate',
        isGreaterThanOrEqualTo: QazaDate.key(QazaDate.normalize(from)),
      );
    }
    if (to != null) {
      query = query.where(
        'originalDate',
        isLessThanOrEqualTo: QazaDate.key(QazaDate.normalize(to)),
      );
    }

    query = query
        .orderBy('originalDate', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (beforeOriginalDate != null) {
      query = query.startAfter([
        QazaDate.key(QazaDate.normalize(beforeOriginalDate)),
        beforeId,
      ]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final documents = hasMore
        ? snapshot.docs.take(limit)
        : snapshot.docs;
    final records = documents.map(_fromDocument).toList(growable: false);

    return QazaHistoryPage(records: records, hasMore: hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    // Firestore remains the remote synchronization implementation. This
    // fallback preserves repository parity without changing the sync design.
    return QazaProgressSummary.fromRecords(await getRecords(userId: userId));
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    final reference = _recordsCollection(record.userId).doc(record.id);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return;
      transaction.set(reference, _toMap(record));
    });
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    for (final record in records) {
      await addRecord(record);
    }
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    await completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty) return;

    final uniqueIds = recordIds.toSet();
    for (final recordId in uniqueIds) {
      final reference = _recordsCollection(userId).doc(recordId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;

        final record = _fromDocument(snapshot);
        if (record.userId != userId) return;

        if (record.status == QazaStatus.completed) {
          final existingCompletedAt = record.completedAt;
          if (existingCompletedAt == null ||
              completedAt.isBefore(existingCompletedAt)) {
            transaction.update(reference, {
              'status': QazaStatus.completed.name,
              'completedAt': Timestamp.fromDate(completedAt),
              'updatedAt': Timestamp.fromDate(completedAt),
            });
          }
          return;
        }

        transaction.update(reference, {
          'status': QazaStatus.completed.name,
          'completedAt': Timestamp.fromDate(completedAt),
          'updatedAt': Timestamp.fromDate(completedAt),
        });
      });
    }
  }

  Map<String, dynamic> _toMap(QazaRecord record) {
    return {
      'userId': record.userId,
      'prayerType': record.prayerType.name,
      // originalDate is a calendar date, so persist it as a date key rather
      // than a Timestamp (an instant that can shift across timezones).
      'originalDate': QazaDate.key(record.originalDate),
      'status': record.status.name,
      'completedAt': record.completedAt == null
          ? null
          : Timestamp.fromDate(record.completedAt!),
      'createdAt': Timestamp.fromDate(record.createdAt),
      'updatedAt': Timestamp.fromDate(record.updatedAt),
    };
  }

  QazaRecord _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw StateError('Qaza record ${document.id} has no data.');
    }

    final prayerName = data['prayerType'] as String?;
    final statusName = data['status'] as String?;
    final prayerType = PrayerType.values.firstWhere(
      (value) => value.name == prayerName,
      orElse: () => throw StateError(
        'Unknown prayer type "$prayerName" in Qaza record ${document.id}.',
      ),
    );
    final status = QazaStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => throw StateError(
        'Unknown Qaza status "$statusName" in record ${document.id}.',
      ),
    );

    return QazaRecord(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      prayerType: prayerType,
      originalDate: _originalDate(data['originalDate'], document.id),
      status: status,
      completedAt: _nullableTimestamp(data['completedAt']),
      createdAt: _timestamp(data['createdAt'], 'createdAt'),
      updatedAt: _timestamp(data['updatedAt'], 'updatedAt'),
    );
  }

  DateTime _originalDate(Object? value, String recordId) {
    if (value is String) return QazaDate.parseKey(value);

    // Legacy records stored originalDate as a Timestamp. The deterministic
    // record ID already contains YYYY-MM-DD, so use it to avoid timezone
    // shifts when reading those records on another device.
    if (value is Timestamp) return QazaDate.fromRecordId(recordId);

    throw StateError('Missing or invalid originalDate in Firestore Qaza record.');
  }

  DateTime _timestamp(Object? value, String fieldName) {
    if (value is Timestamp) return value.toDate();
    throw StateError('Missing or invalid $fieldName in Firestore Qaza record.');
  }

  DateTime? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw StateError('Invalid completedAt in Firestore Qaza record.');
  }
}
