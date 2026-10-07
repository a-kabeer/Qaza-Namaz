
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/diagnostics/diagnostics.dart';

import '../../core/constants/prayer_types.dart';
import 'package:drift/drift.dart' show Value, Variable;

import '../../domain/entities/qaza_record.dart';
import '../../domain/services/conflict_resolver.dart';
import '../local/account_local_store.dart';
import '../local/database/app_database.dart';
import 'firebase_backup_service.dart';
import 'backup_failure.dart';
import 'firebase_services.dart';

class FirebaseReconciliationService {
  FirebaseReconciliationService({
    required FirebaseServices firebase,
    required FirebaseBackupService backupService,
    required AccountLocalStore accountStore,
    required AppDatabase database,
    DiagnosticsService? diagnostics,
  })  : _firebase = firebase,
        _backup = backupService,
        _accountStore = accountStore,
        _database = database,
        _diagnostics = diagnostics ?? const NoopDiagnostics();

  final FirebaseServices _firebase;
  final FirebaseBackupService _backup;
  final AccountLocalStore _accountStore;
  final AppDatabase _database;
  final DiagnosticsService _diagnostics;
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
      final rootResult = await _backup.readCloudRootResult(uid);
      if (!rootResult.isAvailable) {
        await _accountStore.setRestoreState('none');
        return ReconciliationResult(
          cloudAvailable: false,
          failure: rootResult.failure,
        );
      }
      final root = rootResult.data;
      if (root == null) {
        await _accountStore.setRestoreState('none');
        return const ReconciliationResult(cloudAvailable: false);
      }

      final generation = (root['cloudGeneration'] as num?)?.toInt() ?? 1;
      final state = root['datasetState'] as String? ?? 'empty';
      final bootstrapComplete = root['bootstrapComplete'] as bool? ?? false;
      if (state == 'deleting' || state == 'deleted') {
        await _accountStore.setRestoreState('skipped');
        return ReconciliationResult(
          cloudAvailable: true,
          generation: generation,
          skipped: true,
        );
      }
      if (state != 'ready' || !bootstrapComplete) {
        await _accountStore.setRestoreState('skipped');
        return ReconciliationResult(
          cloudAvailable: true,
          generation: generation,
          skipped: true,
          partial: true,
        );
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
      final cloudSnapshots =
          await _readDeletionSnapshots(uid, cloudActions, pageSize: 400);

      _validateCloudDocuments(
        generation: generation,
        documents: <Map<String, dynamic>>[
          ...cloudRecords,
          ...cloudTombstones,
          ...cloudProfileDocs,
          ...cloudAdditions,
          ...cloudActions,
          ...cloudRevisions,
          ...cloudSnapshots,
        ],
      );
      await _assertRestoreContext(localAccountId, uid);

      await _database.transaction(() async {
        await _assertRestoreContext(localAccountId, uid);
        final current = await _accountStore.getAccount(localAccountId);
        if (current != null && generation < current.cloudGeneration) {
          throw StateError(
            'Cloud generation is stale: local=' +
                current.cloudGeneration.toString() +
                ' remote=' +
                generation.toString() +
                '.',
          );
        }
        if (current != null && generation > current.cloudGeneration) {
          await _accountStore.setCloudGeneration(localAccountId, generation);
        }

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
        await _mergeDeletionSnapshots(
          localAccountId: localAccountId,
          cloudSnapshots: cloudSnapshots,
        );
        await _mergePlanRevisions(
          localAccountId: localAccountId,
          cloudRevisions: cloudRevisions,
        );
      });

      await _accountStore.setRestoreState('complete');
      return ReconciliationResult(
        cloudAvailable: true,
        generation: generation,
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

  Future<List<Map<String, dynamic>>> _readDeletionSnapshots(
    String uid,
    List<Map<String, dynamic>> cloudActions, {
    int pageSize = 400,
  }) async {
    final result = <Map<String, dynamic>>[];
    final root = _firebase.firestore.collection('users').doc(uid);
    for (final actionRaw in cloudActions) {
      final actionPayload = _payload(actionRaw);
      final actionId =
          actionPayload['id'] as String? ?? actionRaw['__id'] as String?;
      if (actionId == null || actionId.isEmpty) continue;
      final ref = root.collection('deletionActions').doc(actionId)
          .collection('snapshots');
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query = ref.limit(pageSize);
        if (cursor != null) query = query.startAfterDocument(cursor);
        final page = await query.get();
        if (page.docs.isEmpty) break;
        for (final doc in page.docs) {
          final data = doc.data();
          data['__id'] = doc.id;
          data['__deletionActionId'] = actionId;
          result.add(data);
        }
        if (page.docs.length < pageSize) break;
        cursor = page.docs.last;
      }
    }
    return result;
  }

  void _validateCloudDocuments({
    required int generation,
    required List<Map<String, dynamic>> documents,
  }) {
    for (final raw in documents) {
      final rawGeneration = (raw['cloudGeneration'] as num?)?.toInt();
      if (rawGeneration == null || rawGeneration != generation) {
        throw StateError('Cloud entity generation mismatch.');
      }
      final entityVersion = (raw['entityVersion'] as num?)?.toInt();
      if (entityVersion == null || entityVersion < 1) {
        throw StateError('Cloud entity has invalid entityVersion.');
      }
      if (_date(raw['updatedAt']) == null) {
        throw StateError('Cloud entity has invalid updatedAt.');
      }
      if (raw['writerDeviceId'] is! String ||
          raw['operationId'] is! String ||
          raw['payload'] is! Map) {
        throw StateError('Cloud entity metadata/payload is invalid.');
      }
    }
  }

  Future<void> _assertRestoreContext(String localAccountId, String uid) async {
    final active = await _accountStore.activeAccount();
    if (active?.localAccountId != localAccountId ||
        active?.firebaseUid != uid) {
      throw StateError('Restore result belongs to an inactive account.');
    }
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
      if (record == null) {
        _diagnostics.recordFailure(
          DiagnosticArea.sync,
          'invalid_remote_qaza_record',
          const FormatException(
            'Remote Qaza record failed local schema validation.',
          ),
        );
        continue;
      }

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

    final canonicalIds = byId.keys.toSet();

      // Reconciliation must not clear and reinsert the whole account. Doing
      // so fires local delete triggers for otherwise retained records and can
      // create false tombstones/outbox work. Delete only records that are
      // genuinely absent from the canonical merge.
      for (final record in local) {
        if (canonicalIds.contains(record.id)) continue;
        await _database.qazaRecordsDao.deleteById(
          userId: localAccountId,
          id: record.id,
        );
        await _database.customUpdate(
          'DELETE FROM qaza_profile_plan_provenance '
          'WHERE user_id = ? AND record_id = ?',
          variables: [
            Variable(localAccountId),
            Variable(record.id),
          ],
        );
      }

      // Upsert only the canonical records. Existing retained IDs are updated
      // in place; cloud-only records are inserted with the current account ID.
      if (byId.isNotEmpty) {
        await _database.qazaRecordsDao.upsertRecords(
          byId.values.map(_recordCompanion).toList(growable: false),
        );
      }

      for (final record in byId.values) {
        final provenance =
            record.profilePlanRevisionId == null ||
                    record.profilePlanFingerprint == null
                ? null
                : <String, String>{
                    'revision': record.profilePlanRevisionId!,
                    'fingerprint': record.profilePlanFingerprint!,
                  };
        if (provenance == null) {
          await _database.customUpdate(
            'DELETE FROM qaza_profile_plan_provenance '
            'WHERE user_id = ? AND record_id = ?',
            variables: [
              Variable(localAccountId),
              Variable(record.id),
            ],
          );
        } else {
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
      }

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
        ? VersionedEntity(
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
      final updatedAt = _date(payload['updatedAt']) ?? _date(raw['updatedAt']) ?? DateTime.now();
      final existing = await _database.customSelect(
        '''SELECT revision, updated_at FROM qaza_additions
           WHERE user_id = ? AND id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(id)],
      ).get();
      final remoteStamp = _cloudStamp(raw, id, revision);

      if (existing.isEmpty) {
        await _database.customInsert(
          '''INSERT INTO qaza_additions
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
      } else {
        final row = existing.first;
        final localStamp = await _localStamp(
          localAccountId,
          'qazaAddition',
          id,
          fallbackVersion: row.read<int>('revision'),
          fallbackUpdatedAt: DateTime.parse(row.read<String>('updated_at')),
        );
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

      await _database.customInsert(
        '''INSERT OR REPLACE INTO entity_metadata
           (local_account_id, entity_type, entity_id, entity_version,
            updated_at, writer_device_id, operation_id)
           VALUES (?, 'qazaAddition', ?, ?, ?, ?, ?)''',
        variables: [
          Variable(localAccountId),
          Variable(id),
          Variable(remoteStamp.entityVersion),
          Variable(remoteStamp.updatedAt.microsecondsSinceEpoch),
          Variable(remoteStamp.writerDeviceId),
          Variable(remoteStamp.operationId),
        ],
      );
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
      final remoteUpdatedAt = _date(raw['updatedAt']) ?? (resolved ?? created);
      final remoteStamp = _cloudStamp(raw, id, 1);
      final existing = await _database.customSelect(
        '''SELECT id, addition_id, created_at, resolved_at, entity_version
           FROM qaza_deletion_actions
           WHERE user_id = ? AND id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(id)],
      ).get();

      if (existing.isEmpty) {
        await _database.customInsert(
          '''INSERT INTO qaza_deletion_actions
             (id, user_id, addition_id, created_at, resolved_at, entity_version)
             VALUES (?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable(id),
            Variable(localAccountId),
            Variable(payload['additionId'] as String? ?? ''),
            Variable(created.toIso8601String()),
            Variable(resolved?.toIso8601String()),
            Variable(remoteStamp.entityVersion),
          ],
        );
      } else {
        final row = existing.first;
        final localStamp = await _localStamp(
          localAccountId,
          'deletionAction',
          id,
          fallbackVersion: row.read<int>('entity_version'),
          fallbackUpdatedAt: _date(row.read<String?>('resolved_at')) ?? DateTime.parse(row.read<String>('created_at')),
        );
        if (_resolver.compare(remoteStamp, localStamp) > 0) {
          await _database.customUpdate(
            '''UPDATE qaza_deletion_actions
               SET addition_id = ?, created_at = ?, resolved_at = ?, entity_version = ?
               WHERE user_id = ? AND id = ?''',
            variables: [
              Variable(payload['additionId'] as String? ?? ''),
              Variable(created.toIso8601String()),
              Variable(resolved?.toIso8601String()),
              Variable(remoteStamp.entityVersion),
              Variable(localAccountId),
              Variable(id),
            ],
          );
        }
      }

      await _database.customInsert(
        '''INSERT OR REPLACE INTO entity_metadata
           (local_account_id, entity_type, entity_id, entity_version,
            updated_at, writer_device_id, operation_id)
           VALUES (?, 'deletionAction', ?, ?, ?, ?, ?)''',
        variables: [
          Variable(localAccountId),
          Variable(id),
          Variable(remoteStamp.entityVersion),
          Variable(remoteUpdatedAt.microsecondsSinceEpoch),
          Variable(remoteStamp.writerDeviceId),
          Variable(remoteStamp.operationId),
        ],
      );
    }
  }

  Future<void> _mergeDeletionSnapshots({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudSnapshots,
  }) async {
    for (final raw in cloudSnapshots) {
      final payload = _payload(raw);
      final actionId =
          payload['deletionActionId'] as String? ?? raw['__deletionActionId'] as String?;
      final recordId =
          payload['recordId'] as String? ?? raw['__id'] as String?;
      if (actionId == null || recordId == null || actionId.isEmpty || recordId.isEmpty) {
        continue;
      }

      final additionId = payload['additionId'] as String? ?? '';
      final prayerType = payload['prayerType'] as String? ?? '';
      final originalDate = _date(payload['originalDate']);
      final status = payload['status'] as String? ?? 'pending';
      final completedAt = _date(payload['completedAt']);
      final createdAt = _date(payload['createdAt']) ?? DateTime.now();
      final updatedAt = _date(payload['updatedAt']) ?? createdAt;
      final completionId = payload['completionId'] as String?;
      final recordVersion =
          (payload['recordVersion'] as num?)?.toInt() ??
          (raw['entityVersion'] as num?)?.toInt() ??
          1;
      if (originalDate == null || prayerType.isEmpty) {
        throw StateError('Invalid deletion snapshot payload.');
      }

      final existing = await _database.customSelect(
        '''SELECT addition_id, prayer_type, original_date, status, completed_at,
                  completion_id, created_at, updated_at, record_version
           FROM qaza_deletion_action_record_snapshots
           WHERE deletion_action_id = ? AND record_id = ? AND user_id = ?
           LIMIT 1''',
        variables: [
          Variable(actionId),
          Variable(recordId),
          Variable(localAccountId),
        ],
      ).get();

      if (existing.isEmpty) {
        await _database.customInsert(
          '''INSERT INTO qaza_deletion_action_record_snapshots
             (deletion_action_id, record_id, user_id, addition_id,
              prayer_type, original_date, status, completed_at,
              completion_id, created_at, updated_at, record_version)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable(actionId),
            Variable(recordId),
            Variable(localAccountId),
            Variable(additionId),
            Variable(prayerType),
            Variable(originalDate.toIso8601String()),
            Variable(status),
            Variable(completedAt?.toIso8601String()),
            Variable(completionId),
            Variable(createdAt.toIso8601String()),
            Variable(updatedAt.toIso8601String()),
            Variable(recordVersion),
          ],
        );
      } else {
        final row = existing.first;
        final same = row.read<String>('addition_id') == additionId &&
            row.read<String>('prayer_type') == prayerType &&
            row.read<String>('original_date') == originalDate.toIso8601String() &&
            row.read<String>('status') == status &&
            row.read<String?>('completed_at') == completedAt?.toIso8601String() &&
            row.read<String?>('completion_id') == completionId &&
            row.read<String>('created_at') == createdAt.toIso8601String() &&
            row.read<String>('updated_at') == updatedAt.toIso8601String() &&
            row.read<int>('record_version') == recordVersion;
        if (!same) {
          throw StateError('Deletion snapshot conflict: $actionId/$recordId');
        }
      }

      await _database.customInsert(
        '''INSERT OR REPLACE INTO entity_metadata
           (local_account_id, entity_type, entity_id, entity_version,
            updated_at, writer_device_id, operation_id)
           VALUES (?, 'deletionSnapshot', ?, ?, ?, ?, ?)''',
        variables: [
          Variable(localAccountId),
          Variable('$actionId/$recordId'),
          Variable((raw['entityVersion'] as num?)?.toInt() ?? recordVersion),
          Variable((_date(raw['updatedAt']) ?? updatedAt).microsecondsSinceEpoch),
          Variable(raw['writerDeviceId'] as String),
          Variable(raw['operationId'] as String),
        ],
      );
    }
  }

  Future<void> _mergePlanRevisions({
    required String localAccountId,
    required List<Map<String, dynamic>> cloudRevisions,
  }) async {
    for (final raw in cloudRevisions) {
      final payload = _payload(raw);
      final revisionId = payload['revisionId'] as String? ?? raw['__id'] as String?;
      if (revisionId == null || revisionId.isEmpty) continue;
      final encoded = jsonEncode(payload);
      final createdAt = _date(payload['createdAt']) ?? DateTime.now();
      final existing = await _database.customSelect(
        '''SELECT payload_json FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ? LIMIT 1''',
        variables: [Variable(localAccountId), Variable(revisionId)],
      ).get();
      if (existing.isEmpty) {
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

      final stamp = _cloudStamp(raw, revisionId, 1);
      await _database.customInsert(
        '''INSERT OR REPLACE INTO entity_metadata
           (local_account_id, entity_type, entity_id, entity_version,
            updated_at, writer_device_id, operation_id)
           VALUES (?, 'qazaPlanRevision', ?, ?, ?, ?, ?)''',
        variables: [
          Variable(localAccountId),
          Variable(revisionId),
          Variable(stamp.entityVersion),
          Variable(stamp.updatedAt.microsecondsSinceEpoch),
          Variable(stamp.writerDeviceId),
          Variable(stamp.operationId),
        ],
      );
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
      final id = payload['id'];
      final cloudUserId = payload['userId'];
      final prayer = payload['prayerType'];
      final status = payload['status'];
      if (id is! String ||
          id.isEmpty ||
          cloudUserId is! String ||
          cloudUserId.isEmpty ||
          prayer is! String ||
          status is! String ||
          !['pending', 'completed'].contains(status) ||
          !_validPrayerType(prayer) ||
          _date(payload['originalDate']) == null ||
          _date(payload['createdAt']) == null ||
          _date(payload['updatedAt']) == null ||
          payload['recordVersion'] is! num ||
          (payload['recordVersion'] as num).toInt() < 1) {
        throw const FormatException('Remote Qaza record payload is malformed.');
      }
      return QazaRecord(
        id: id,
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

  bool _validPrayerType(String value) =>
      PrayerType.values.any((candidate) => candidate.name == value);

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
    this.failure,
  });

  final bool cloudAvailable;
  final int? generation;
  final bool partial;
  final bool skipped;
  final BackupFailure? failure;
}
