
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/prayer_types.dart';
import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import '../../domain/services/conflict_resolver.dart';
import '../local/account_local_store.dart';
import '../local/database/app_database.dart';
import 'firebase_backup_service.dart';
import 'firebase_services.dart';

class FirebaseReconciliationService {
  FirebaseReconciliationService({
    required FirebaseServices firebase,
    required FirebaseBackupService backupService,
    required AccountLocalStore accountStore,
    required AppDatabase database,
  })  : _firebase = firebase,
        _backup = backupService,
        _accountStore = accountStore,
        _database = database;

  final FirebaseServices _firebase;
  final FirebaseBackupService _backup;
  final AccountLocalStore _accountStore;
  final AppDatabase _database;
  final ConflictResolver _resolver = const ConflictResolver();

  Future<ReconciliationResult> restore({
    required String localAccountId,
    required String uid,
  }) async {
    if (!await _firebase.initialize()) {
      return const ReconciliationResult(cloudAvailable: false);
    }

    await _accountStore.setRestoreState('inProgress');
    try {
      final root = await _backup.readCloudRoot(uid);
      if (root == null) {
        await _accountStore.setRestoreState('none');
        return const ReconciliationResult(cloudAvailable: false);
      }

      final generation = (root['cloudGeneration'] as num?)?.toInt() ?? 1;
      final state = root['datasetState'] as String? ?? 'empty';
      if (state == 'deleting' || state == 'deleted') {
        await _accountStore.setRestoreState('skipped');
        return ReconciliationResult(
          cloudAvailable: true,
          generation: generation,
          skipped: true,
        );
      }

      final current = await _accountStore.getAccount(localAccountId);
      if (current != null && generation != current.cloudGeneration) {
        await _accountStore.setCloudGeneration(localAccountId, generation);
      }

      final cloudRecords =
          await _readCollection(uid, 'qazaRecords', pageSize: 400);
      final cloudTombstones =
          await _readCollection(uid, 'qazaRecordTombstones', pageSize: 400);
      final cloudProfileDocs =
          await _readCollection(uid, 'profile', pageSize: 50);
      final cloudAdditions =
          await _readCollection(uid, 'qazaAdditions', pageSize: 400);
      final cloudActions =
          await _readCollection(uid, 'deletionActions', pageSize: 400);
      final cloudRevisions =
          await _readCollection(uid, 'qazaPlanRevisions', pageSize: 400);

      await _mergeQazaRecords(
        localAccountId: localAccountId,
        cloudRecords: cloudRecords,
        cloudTombstones: cloudTombstones,
      );
      await _mergeProfile(
        localAccountId: localAccountId,
        cloudProfileDocs: cloudProfileDocs,
      );
      await _mergeAdditions(
        localAccountId: localAccountId,
        cloudAdditions: cloudAdditions,
      );
      await _mergeDeletionActions(
        localAccountId: localAccountId,
        cloudActions: cloudActions,
      );
      await _mergePlanRevisions(
        localAccountId: localAccountId,
        cloudRevisions: cloudRevisions,
      );

      await _accountStore.setRestoreState('complete');
      return ReconciliationResult(
        cloudAvailable: true,
        generation: generation,
        partial: state == 'initializing',
      );
    } catch (error) {
      await _accountStore.setRestoreState('failed');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _readCollection(
    String uid,
    String collection, {
    int pageSize = 400,
  }) async {
    final ref =
        _firebase.firestore.collection('users').doc(uid).collection(collection);
    final result = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = ref.limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      if (page.docs.isEmpty) break;
      for (final doc in page.docs) {
        final data = doc.data();
        data['__id'] = doc.id;
        result.add(data);
      }
      if (page.docs.length < pageSize) break;
      cursor = page.docs.last;
    }
    return result;
  }

  Future<void> _mergeQazaRecords({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudRecords,
    required List<Map<String, dynamic>> cloudTombstones,
  }) async {
    final local =
        await _database.qazaRecordsDao.getAll(userId: localAccountId);

    final byId = <String, QazaRecord>{for (final record in local) record.id: record};
    final byKey = <String, QazaRecord>{
      for (final record in local)
        _businessKey(record.userId, record.prayerType.name, record.originalDate):
            record,
    };

    for (final raw in cloudRecords) {
      final payload = _payload(raw);
      final record = _cloudRecord(localAccountId, payload);
      if (record == null) continue;

      final existingId = byId[record.id];
      if (existingId != null) {
        final localStamp = await _localStamp(
          localAccountId,
          'qazaRecord',
          existingId.id,
          fallbackVersion: existingId.recordVersion,
          fallbackUpdatedAt: existingId.updatedAt,
        );
        final remoteStamp = _cloudStamp(raw, record.id, record.recordVersion);
        if (_resolver.compare(remoteStamp, localStamp) > 0) {
          byId[record.id] = record;
        }
        continue;
      }

      final key = _businessKey(
        localAccountId,
        record.prayerType.name,
        record.originalDate,
      );
      final collision = byKey[key];
      if (collision == null) {
        byId[record.id] = record;
        byKey[key] = record;
      } else {
        final localStamp = await _localStamp(
          localAccountId,
          'qazaRecord',
          collision.id,
          fallbackVersion: collision.recordVersion,
          fallbackUpdatedAt: collision.updatedAt,
        );
        final remoteStamp = _cloudStamp(raw, record.id, record.recordVersion);
        if (_resolver.compare(remoteStamp, localStamp) > 0) {
          byId.remove(collision.id);
          byId[record.id] = record;
          byKey[key] = record;
        }
      }
    }

    for (final raw in cloudTombstones) {
      final payload = _payload(raw);
      final recordId = payload['recordId'] as String? ?? raw['__id'] as String?;
      if (recordId == null || recordId.isEmpty) continue;
      final tombstoneVersion =
          (payload['recordVersion'] as num?)?.toInt() ??
          (raw['entityVersion'] as num?)?.toInt() ??
          0;
      final localRecord = byId[recordId];
      if (localRecord != null && tombstoneVersion >= localRecord.recordVersion) {
        byId.remove(recordId);
      }
      final updatedAt = _date(payload['deletedAt']) ??
          _date(raw['updatedAt']) ??
          DateTime.now();
      final writer = raw['writerDeviceId'] as String? ?? '';
      final operation = raw['operationId'] as String? ?? raw['__id'] as String;
      final existing = await _database.customSelect(
        '''SELECT record_version FROM qaza_record_tombstones
           WHERE local_account_id = ? AND record_id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(recordId)],
      ).get();
      final existingVersion =
          existing.isEmpty ? -1 : existing.first.read<int>('record_version');
      if (tombstoneVersion >= existingVersion) {
        await _database.customInsert(
          '''INSERT OR REPLACE INTO qaza_record_tombstones
             (local_account_id, record_id, record_version, deleted_at,
              writer_device_id, operation_id, cloud_generation)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable(localAccountId),
            Variable(recordId),
            Variable(tombstoneVersion),
            Variable(updatedAt.microsecondsSinceEpoch),
            Variable(writer),
            Variable(operation),
            Variable((raw['cloudGeneration'] as num?)?.toInt() ?? 1),
          ],
        );
      }
    }

    await _database.transaction(() async {
      await _database.qazaRecordsDao.replaceUserRecords(
        userId: localAccountId,
        records: byId.values.map(_recordCompanion).toList(growable: false),
      );
      for (final record in byId.values) {
        final provenance =
            record.profilePlanRevisionId == null ||
                    record.profilePlanFingerprint == null
                ? null
                : <String, String>{
                    'revision': record.profilePlanRevisionId!,
                    'fingerprint': record.profilePlanFingerprint!,
                  };
        if (provenance == null) continue;
        await _database.customInsert(
          '''INSERT OR REPLACE INTO qaza_profile_plan_provenance
             (record_id, user_id, plan_revision_id, plan_fingerprint)
             VALUES (?, ?, ?, ?)''',
          variables: [
            Variable(record.id),
            Variable(localAccountId),
            Variable(provenance['revision']),
            Variable(provenance['fingerprint']),
          ],
        );
      }
    });
  }

  Future<void> _mergeProfile({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudProfileDocs,
  }) async {
    if (cloudProfileDocs.isEmpty) return;
    final current = await _database.customSelect(
      '''SELECT entity_version, updated_at, writer_device_id, operation_id
         FROM account_profiles WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();

    final raw = cloudProfileDocs.first;
    final payload = _payload(raw)['profile'];
    if (payload is! Map) return;

    final remoteStamp = _cloudStamp(
      raw,
      localAccountId,
      (raw['entityVersion'] as num?)?.toInt() ?? 1,
    );
    final localStamp = current.isEmpty
        ? const VersionedEntity(
            entityVersion: 0,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            writerDeviceId: '',
            operationId: '',
            entityId: 'profile',
          )
        : VersionedEntity(
            entityVersion: current.first.read<int>('entity_version'),
            updatedAt: _microsToDate(current.first.read<int>('updated_at')),
            writerDeviceId: current.first.read<String>('writer_device_id'),
            operationId: current.first.read<String>('operation_id'),
            entityId: 'profile',
          );

    if (_resolver.compare(remoteStamp, localStamp) <= 0) return;

    await _database.customInsert(
      '''INSERT OR REPLACE INTO account_profiles
         (local_account_id, payload_json, entity_version, updated_at,
          writer_device_id, operation_id)
         VALUES (?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable(localAccountId),
        Variable(jsonEncode(Map<String, dynamic>.from(payload))),
        Variable(remoteStamp.entityVersion),
        Variable(remoteStamp.updatedAt.microsecondsSinceEpoch),
        Variable(remoteStamp.writerDeviceId),
        Variable(remoteStamp.operationId),
      ],
    );
  }

  Future<void> _mergeAdditions({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudAdditions,
  }) async {
    for (final raw in cloudAdditions) {
      final payload = _payload(raw);
      final id = payload['id'] as String? ?? raw['__id'] as String?;
      if (id == null || id.isEmpty) continue;
      final revision = (payload['revision'] as num?)?.toInt() ?? 1;
      final updatedAt = _date(payload['updatedAt']) ??
          _date(raw['updatedAt']) ??
          DateTime.now();
      final existing = await _database.customSelect(
        '''SELECT revision, updated_at FROM qaza_additions
           WHERE user_id = ? AND id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(id)],
      ).get();
      if (existing.isEmpty) {
        await _database.customInsert(
          '''INSERT OR IGNORE INTO qaza_additions
             (id, user_id, mode, input_snapshot, revision, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable(id),
            Variable(localAccountId),
            Variable(payload['mode'] as String? ?? 'single'),
            Variable(jsonEncode(payload['currentInputSnapshot'])),
            Variable(revision),
            Variable((_date(payload['createdAt']) ?? updatedAt).toIso8601String()),
            Variable(updatedAt.toIso8601String()),
          ],
        );
        continue;
      }
      final localRevision = existing.first.read<int>('revision');
      final localUpdated = DateTime.parse(existing.first.read<String>('updated_at'));
      final localStamp = VersionedEntity(
        entityVersion: localRevision,
        updatedAt: localUpdated,
        writerDeviceId: '',
        operationId: '',
        entityId: id,
      );
      final remoteStamp = _cloudStamp(raw, id, revision);
      if (_resolver.compare(remoteStamp, localStamp) > 0) {
        await _database.customUpdate(
          '''UPDATE qaza_additions
             SET mode = ?, input_snapshot = ?, revision = ?, updated_at = ?
             WHERE user_id = ? AND id = ?''',
          variables: [
            Variable(payload['mode'] as String? ?? 'single'),
            Variable(jsonEncode(payload['currentInputSnapshot'])),
            Variable(revision),
            Variable(updatedAt.toIso8601String()),
            Variable(localAccountId),
            Variable(id),
          ],
        );
      }
    }
  }

  Future<void> _mergeDeletionActions({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudActions,
  }) async {
    for (final raw in cloudActions) {
      final payload = _payload(raw);
      final id = payload['id'] as String? ?? raw['__id'] as String?;
      if (id == null || id.isEmpty) continue;
      final created = _date(payload['createdAt']) ?? DateTime.now();
      final resolved = _date(payload['resolvedAt']);
      final existing = await _database.customSelect(
        'SELECT id FROM qaza_deletion_actions WHERE user_id = ? AND id = ? LIMIT 1',
        variables: [Variable(localAccountId), Variable(id)],
      ).get();
      if (existing.isEmpty) {
        await _database.customInsert(
          '''INSERT OR IGNORE INTO qaza_deletion_actions
             (id, user_id, addition_id, created_at, resolved_at)
             VALUES (?, ?, ?, ?, ?)''',
          variables: [
            Variable(id),
            Variable(localAccountId),
            Variable(payload['additionId'] as String? ?? ''),
            Variable(created.toIso8601String()),
            Variable(resolved?.toIso8601String()),
          ],
        );
      }
    }
  }

  Future<void> _mergePlanRevisions({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudRevisions,
  }) async {
    for (final raw in cloudRevisions) {
      final payload = _payload(raw);
      final revisionId =
          payload['revisionId'] as String? ?? raw['__id'] as String?;
      if (revisionId == null || revisionId.isEmpty) continue;
      final encoded = jsonEncode(payload);
      final existing = await _database.customSelect(
        '''SELECT payload_json FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(revisionId)],
      ).get();
      if (existing.isEmpty) {
        final createdAt = _date(payload['createdAt']) ?? DateTime.now();
        await _database.customInsert(
          '''INSERT INTO account_plan_revisions
             (local_account_id, revision_id, payload_json, created_at)
             VALUES (?, ?, ?, ?)''',
          variables: [
            Variable(localAccountId),
            Variable(revisionId),
            Variable(encoded),
            Variable(createdAt.microsecondsSinceEpoch),
          ],
        );
      } else if (existing.first.read<String>('payload_json') != encoded) {
        throw StateError('Immutable QazaPlanRevision conflict: $revisionId');
      }
    }
  }

  Future<VersionedEntity> _localStamp(
    String localId,
    String type,
    String id, {
    required int fallbackVersion,
    required DateTime fallbackUpdatedAt,
  }) async {
    final rows = await _database.customSelect(
      '''SELECT entity_version, updated_at, writer_device_id, operation_id
         FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = ? AND entity_id = ?
         LIMIT 1''',
      variables: [Variable(localId), Variable(type), Variable(id)],
    ).get();
    if (rows.isEmpty) {
      return VersionedEntity(
        entityVersion: fallbackVersion,
        updatedAt: fallbackUpdatedAt,
        writerDeviceId: '',
        operationId: 'legacy_$id',
        entityId: id,
      );
    }
    final row = rows.first;
    return VersionedEntity(
      entityVersion: row.read<int>('entity_version'),
      updatedAt: _microsToDate(row.read<int>('updated_at')),
      writerDeviceId: row.read<String>('writer_device_id'),
      operationId: row.read<String>('operation_id'),
      entityId: id,
    );
  }

  VersionedEntity _cloudStamp(
    Map<String, dynamic> raw,
    String id,
    int fallbackVersion,
  ) =>
      VersionedEntity(
        entityVersion:
            (raw['entityVersion'] as num?)?.toInt() ?? fallbackVersion,
        updatedAt: _date(raw['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        writerDeviceId: raw['writerDeviceId'] as String? ?? '',
        operationId: raw['operationId'] as String? ?? raw['__id'] as String,
        entityId: id,
      );

  Map<String, dynamic> _payload(Map<String, dynamic> raw) {
    final value = raw['payload'];
    if (value is Map) return Map<String, dynamic>.from(value);
    return raw;
  }

  QazaRecord? _cloudRecord(
    String localAccountId,
    Map<String, dynamic> payload,
  ) {
    try {
      final prayer = payload['prayerType'] as String;
      final status = payload['status'] as String? ?? 'pending';
      return QazaRecord(
        id: payload['id'] as String,
        userId: localAccountId,
        prayerType:
            PrayerType.values.firstWhere((value) => value.name == prayer),
        originalDate: _date(payload['originalDate'])!,
        status: QazaStatus.values.firstWhere((value) => value.name == status),
        completedAt: _date(payload['completedAt']),
        completionId: payload['completionId'] as String?,
        additionId: payload['additionId'] as String?,
        profilePlanRevisionId: payload['profilePlanRevisionId'] as String?,
        profilePlanFingerprint: payload['profilePlanFingerprint'] as String?,
        recordVersion: (payload['recordVersion'] as num?)?.toInt() ?? 1,
        createdAt: _date(payload['createdAt'])!,
        updatedAt: _date(payload['updatedAt'])!,
      );
    } catch (_) {
      return null;
    }
  }

  String _businessKey(String userId, String prayer, DateTime date) =>
      userId + '|' + prayer + '|' + date.year.toString() + '-' +
      date.month.toString().padLeft(2, '0') + '-' +
      date.day.toString().padLeft(2, '0');

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime _microsToDate(int micros) =>
      DateTime.fromMicrosecondsSinceEpoch(micros);

  QazaRecordsCompanion _recordCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
        id: record.id,
        userId: record.userId,
        prayerType: record.prayerType.name,
        originalDate: record.originalDate,
        status: record.status.name,
        completedAt: record.completedAt == null
            ? const Value.absent()
            : Value(record.completedAt),
        completionId: record.completionId == null
            ? const Value.absent()
            : Value(record.completionId),
        additionId: Value(record.additionId),
        recordVersion: Value(record.recordVersion),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
}

class ReconciliationResult {
  const ReconciliationResult({
    required this.cloudAvailable,
    this.generation,
    this.partial = false,
    this.skipped = false,
  });

  final bool cloudAvailable;
  final int? generation;
  final bool partial;
  final bool skipped;
}
