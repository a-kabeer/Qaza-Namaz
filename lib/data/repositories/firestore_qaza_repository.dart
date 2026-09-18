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

  CollectionReference<Map<String, dynamic>> _recordsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('qazaRecords');

  @override
  Future<List<QazaRecord>> getRecords(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null)
      query = query.where('prayerType', isEqualTo: prayerType.name);
    if (status != null) query = query.where('status', isEqualTo: status.name);
    final records = (await query.get()).docs.map(_fromDocument).toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
  }

  @override
  Future<QazaPage> getPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status,
      DateTime? from,
      DateTime? to,
      DateTime? afterOriginalDate,
      String? afterId}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((afterOriginalDate == null) != (afterId == null))
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    if (from != null && to != null && from.isAfter(to))
      throw ArgumentError('from must be <= to');
    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null)
      query = query.where('prayerType', isEqualTo: prayerType.name);
    if (status != null) query = query.where('status', isEqualTo: status.name);
    if (from != null)
      query = query.where('originalDate',
          isGreaterThanOrEqualTo: QazaDate.key(QazaDate.normalize(from)));
    if (to != null)
      query = query.where('originalDate',
          isLessThanOrEqualTo: QazaDate.key(QazaDate.normalize(to)));
    query = query.orderBy('originalDate').orderBy(FieldPath.documentId);
    if (afterOriginalDate != null)
      query = query.startAfter(
          [QazaDate.key(QazaDate.normalize(afterOriginalDate)), afterId]);
    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.take(limit) : snapshot.docs;
    return QazaPage(
        records: docs.map(_fromDocument).toList(growable: false),
        hasMore: hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await getPage(
        userId: userId,
        limit: 1,
        prayerType: prayerType,
        status: QazaStatus.pending);
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status = QazaStatus.completed,
      DateTime? from,
      DateTime? to,
      DateTime? beforeOriginalDate,
      String? beforeId}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if (from != null && to != null && from.isAfter(to))
      throw ArgumentError('from must be <= to');
    if ((beforeOriginalDate == null) != (beforeId == null))
      throw ArgumentError(
          'beforeOriginalDate and beforeId must be provided together');
    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null)
      query = query.where('prayerType', isEqualTo: prayerType.name);
    if (status != null) query = query.where('status', isEqualTo: status.name);
    if (from != null)
      query = query.where('originalDate',
          isGreaterThanOrEqualTo: QazaDate.key(QazaDate.normalize(from)));
    if (to != null)
      query = query.where('originalDate',
          isLessThanOrEqualTo: QazaDate.key(QazaDate.normalize(to)));
    query = query
        .orderBy('originalDate', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (beforeOriginalDate != null)
      query = query.startAfter(
          [QazaDate.key(QazaDate.normalize(beforeOriginalDate)), beforeId]);
    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final docs = hasMore ? snapshot.docs.take(limit) : snapshot.docs;
    return QazaHistoryPage(
        records: docs.map(_fromDocument).toList(growable: false),
        hasMore: hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
          {required String userId}) async =>
      QazaProgressSummary.fromRecords(await getRecords(userId: userId));

  @override
  Future<void> addRecord(QazaRecord record) async {
    final reference = _recordsCollection(record.userId).doc(record.id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) transaction.set(reference, _toMap(record));
    });
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    for (final record in records) await addRecord(record);
  }

  @override
  Future<void> completeRecord(
          {required String userId,
          required String recordId,
          required DateTime completedAt}) =>
      completeRecords(
          userId: userId, recordIds: [recordId], completedAt: completedAt);

  @override
  Future<void> completeRecords(
      {required String userId,
      required List<String> recordIds,
      required DateTime completedAt}) async {
    for (final recordId in recordIds.toSet()) {
      final reference = _recordsCollection(userId).doc(recordId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;
        final record = _fromDocument(snapshot);
        if (record.userId != userId) return;
        final existingCompletedAt = record.completedAt;
        if (record.status == QazaStatus.completed &&
            existingCompletedAt != null &&
            !completedAt.isBefore(existingCompletedAt)) return;
        transaction.update(reference, {
          'status': QazaStatus.completed.name,
          'completedAt': Timestamp.fromDate(completedAt),
          'updatedAt': Timestamp.fromDate(completedAt)
        });
      });
    }
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    final collection = _recordsCollection(userId);
    // Firestore has no collection-level delete, and a write batch is capped at
    // 500 operations, so the ledger is drained page by page.
    while (true) {
      final snapshot = await collection.limit(_deleteBatchSize).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) batch.delete(document.reference);
      await batch.commit();
      if (snapshot.docs.length < _deleteBatchSize) return;
    }
  }

  static const int _deleteBatchSize = 400;

  Map<String, dynamic> _toMap(QazaRecord record) => {
        'userId': record.userId,
        'prayerType': record.prayerType.name,
        'originalDate': QazaDate.key(record.originalDate),
        'status': record.status.name,
        'completedAt': record.completedAt == null
            ? null
            : Timestamp.fromDate(record.completedAt!),
        'createdAt': Timestamp.fromDate(record.createdAt),
        'updatedAt': Timestamp.fromDate(record.updatedAt)
      };

  QazaRecord _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null)
      throw StateError('Qaza record ${document.id} has no data.');
    final prayerType = PrayerType.values.firstWhere(
        (value) => value.name == data['prayerType'],
        orElse: () =>
            throw StateError('Unknown prayer type in record ${document.id}.'));
    final status = QazaStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () =>
            throw StateError('Unknown Qaza status in record ${document.id}.'));
    return QazaRecord(
        id: document.id,
        userId: data['userId'] as String? ?? '',
        prayerType: prayerType,
        originalDate: _originalDate(data['originalDate'], document.id),
        status: status,
        completedAt: _nullableTimestamp(data['completedAt']),
        createdAt: _timestamp(data['createdAt'], 'createdAt'),
        updatedAt: _timestamp(data['updatedAt'], 'updatedAt'));
  }

  DateTime _originalDate(Object? value, String id) {
    if (value is String) return QazaDate.parseKey(value);
    if (value is Timestamp) return QazaDate.fromRecordId(id);
    throw StateError(
        'Missing or invalid originalDate in Firestore Qaza record.');
  }

  DateTime _timestamp(Object? value, String field) {
    if (value is Timestamp) return value.toDate();
    throw StateError('Missing or invalid $field in Firestore Qaza record.');
  }

  DateTime? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw StateError('Invalid completedAt in Firestore Qaza record.');
  }
}
