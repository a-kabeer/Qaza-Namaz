import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';

class FirestoreQazaRepository implements QazaRepository {
  FirestoreQazaRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _recordsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('qazaRecords');
  }

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _recordsCollection(userId);

    if (prayerType != null) query = query.where('prayerType', isEqualTo: prayerType.name);
    if (status != null) query = query.where('status', isEqualTo: status.name);

    final snapshot = await query.get();
    final records = snapshot.docs.map(_fromDocument).toList();
    records.sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? originalDateFrom,
    DateTime? originalDateTo,
    String? cursor,
    int limit = 25,
    bool ascending = false,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    }

    Query<Map<String, dynamic>> query = _recordsCollection(userId);
    if (prayerType != null) query = query.where('prayerType', isEqualTo: prayerType.name);
    if (status != null) query = query.where('status', isEqualTo: status.name);

    final from = originalDateFrom == null ? null : QazaDate.key(originalDateFrom);
    final to = originalDateTo == null ? null : QazaDate.key(originalDateTo);
    if (from != null) query = query.where('originalDate', isGreaterThanOrEqualTo: from);
    if (to != null) query = query.where('originalDate', isLessThanOrEqualTo: to);

    final direction = ascending ? QueryDirection.ascending : QueryDirection.descending;
    query = query.orderBy('originalDate', descending: !ascending);
    query = query.orderBy(FieldPath.documentId, descending: !ascending);

    if (cursor != null) {
      final decoded = _decodeCursor(cursor);
      query = query.startAfter([decoded.dateKey, decoded.id]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final documents = snapshot.docs;
    final hasMore = documents.length > limit;
    final pageDocuments = hasMore ? documents.take(limit).toList() : documents;
    final records = pageDocuments.map(_fromDocument).toList();

    return QazaHistoryPage(
      records: List.unmodifiable(records),
      nextCursor: hasMore && pageDocuments.isNotEmpty
          ? _encodeCursor(pageDocuments.last)
          : null,
    );
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
    for (final record in records) await addRecord(record);
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) => completeRecords(userId: userId, recordIds: [recordId], completedAt: completedAt);

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty) return;
    for (final recordId in recordIds.toSet()) {
      final reference = _recordsCollection(userId).doc(recordId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;
        final record = _fromDocument(snapshot);
        if (record.userId != userId) return;
        if (record.status == QazaStatus.completed) {
          final existingCompletedAt = record.completedAt;
          if (existingCompletedAt == null || completedAt.isBefore(existingCompletedAt)) {
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

  Map<String, dynamic> _toMap(QazaRecord record) => {
        'userId': record.userId,
        'prayerType': record.prayerType.name,
        'originalDate': QazaDate.key(record.originalDate),
        'status': record.status.name,
        'completedAt': record.completedAt == null ? null : Timestamp.fromDate(record.completedAt!),
        'createdAt': Timestamp.fromDate(record.createdAt),
        'updatedAt': Timestamp.fromDate(record.updatedAt),
      };

  QazaRecord _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) throw StateError('Qaza record ${document.id} has no data.');
    final prayerName = data['prayerType'] as String?;
    final statusName = data['status'] as String?;
    final prayerType = PrayerType.values.firstWhere(
      (value) => value.name == prayerName,
      orElse: () => throw StateError('Unknown prayer type "$prayerName" in Qaza record ${document.id}.'),
    );
    final status = QazaStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => throw StateError('Unknown Qaza status "$statusName" in record ${document.id}.'),
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

  String _encodeCursor(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    return base64UrlEncode(utf8.encode(jsonEncode({
      'date': document.data()['originalDate'],
      'id': document.id,
    })));
  }

  _HistoryCursor _decodeCursor(String value) {
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(value)))) as Map<String, dynamic>;
      final date = json['date'] as String?;
      final id = json['id'] as String?;
      if (date == null || id == null || id.isEmpty) throw const FormatException();
      return _HistoryCursor(date, id);
    } catch (_) {
      throw ArgumentError.value(value, 'cursor', 'invalid history cursor');
    }
  }
}

class _HistoryCursor {
  const _HistoryCursor(this.dateKey, this.id);
  final String dateKey;
  final String id;
}
