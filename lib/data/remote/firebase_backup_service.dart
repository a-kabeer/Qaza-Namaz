
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import '../../domain/services/conflict_resolver.dart';
import '../local/account_local_store.dart';
import '../local/database/app_database.dart';
import 'firebase_services.dart';

class FirebaseBackupService {
  FirebaseBackupService({
    required FirebaseServices firebase,
    required AppDatabase database,
    required AccountLocalStore accountStore,
  })  : _firebase = firebase,
        _database = database,
        _accountStore = accountStore;

  final FirebaseServices _firebase;
  final AppDatabase _database;
  final AccountLocalStore _accountStore;
  final ConflictResolver _resolver = const ConflictResolver();

  static const cloudSchemaVersion = 1;

  Future<Map<String, dynamic>?> readCloudRoot(String uid) async {
    if (!await _firebase.initialize()) return null;
    final snap = await _firebase.firestore.collection('users').doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> bootstrapAccount({
    required String localAccountId,
    required String uid,
    required int generation,
  }) async {
    final bootstrapCutoffMicros = DateTime.now().microsecondsSinceEpoch;
    await _ensureCloudGeneration(
      uid: uid,
      expectedGeneration: generation,
      allowCreate: true,
    );
    await snapshotAccount(
      localAccountId: localAccountId,
      uid: uid,
      generation: generation,
      bootstrapCutoffMicros: bootstrapCutoffMicros,
    );
  }

  Future<void> snapshotAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    int? bootstrapCutoffMicros,
  }) async {
    if (!await _firebase.initialize()) return;

    final rootRef = _firebase.firestore.collection('users').doc(uid);
    final root = await rootRef.get();
    if (root.exists) {
      final data = root.data() ?? const <String, dynamic>{};
      final remoteGeneration = (data['cloudGeneration'] as num?)?.toInt() ?? 1;
      final remoteState = data['datasetState'] as String? ?? 'empty';
      if (remoteGeneration != generation) {
        throw StateError(
          'Cloud generation mismatch: local=$generation remote=$remoteGeneration.',
        );
      }
      if (remoteState == 'deleting' || remoteState == 'deleted') {
        throw StateError('Cloud dataset is not writable in state $remoteState.');
      }
    } else {
      await rootRef.set({
        'schemaVersion': cloudSchemaVersion,
        'cloudGeneration': generation,
        'datasetState': 'initializing',
        'updatedAt': FieldValue.serverTimestamp(),
        'bootstrapComplete': false,
      });
    }

    if (bootstrapCutoffMicros != null) {
      await _firebase.firestore.runTransaction((transaction) async {
        final snap = await transaction.get(rootRef);
        if (!snap.exists) {
          throw StateError('Cloud account root disappeared before bootstrap.');
        }
        final data = snap.data() ?? const <String, dynamic>{};
        final actualGeneration =
            (data['cloudGeneration'] as num?)?.toInt() ?? 0;
        final state = data['datasetState'] as String? ?? 'empty';
        if (actualGeneration != generation ||
            (state != 'initializing' && state != 'ready')) {
          throw StateError(
            'Cloud dataset changed before bootstrap marker was stored.',
          );
        }
        transaction.set(
          rootRef,
          {'bootstrapCutoffMicros': bootstrapCutoffMicros},
          SetOptions(merge: true),
        );
      });
    }

    await _writeProfile(localAccountId, uid, generation);
    await _writeQazaRecords(localAccountId, uid, generation);
    await _writeQazaAdditions(localAccountId, uid, generation);
    await _writeDeletionActions(localAccountId, uid, generation);
    await _writePlanRevisions(localAccountId, uid, generation);
    await _writeTombstones(localAccountId, uid, generation);

    if (bootstrapCutoffMicros != null &&
        await _hasOutboxMutationAfter(localAccountId, bootstrapCutoffMicros)) {
      throw StateError(
        'Local mutation occurred during cloud bootstrap; retry bootstrap.',
      );
    }

    await _firebase.firestore.runTransaction((transaction) async {
      final snap = await transaction.get(rootRef);
      if (!snap.exists) {
        throw StateError('Cloud account root disappeared during backup.');
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final currentGeneration =
          (data['cloudGeneration'] as num?)?.toInt() ?? 0;
      final state = data['datasetState'] as String? ?? 'empty';
      final storedCutoff =
          (data['bootstrapCutoffMicros'] as num?)?.toInt();
      if (currentGeneration != generation ||
          (state != 'initializing' && state != 'ready') ||
          (bootstrapCutoffMicros != null &&
              storedCutoff != bootstrapCutoffMicros)) {
        throw StateError(
          'Cloud dataset changed before backup completion: '
          'generation=' +
              currentGeneration.toString() +
              ' state=' +
              state,
        );
      }
      transaction.set(
        rootRef,
        {
          'schemaVersion': cloudSchemaVersion,
          'cloudGeneration': generation,
          'datasetState': 'ready',
          'updatedAt': FieldValue.serverTimestamp(),
          'bootstrapComplete': true,
        },
        SetOptions(merge: true),
      );
    });
  }


  Future<void> deleteCloudData({
    required String uid,
    required int expectedGeneration,
    required int newGeneration,
  }) async {
    if (!await _firebase.initialize()) {
      throw StateError('Firebase is unavailable.');
    }

    final rootRef = _firebase.firestore.collection('users').doc(uid);
    final root = await rootRef.get();
    if (root.exists) {
      final data = root.data() ?? const <String, dynamic>{};
      final current =
          (data['cloudGeneration'] as num?)?.toInt() ?? expectedGeneration;
      final state = data['datasetState'] as String? ?? 'empty';
      if (state == 'deleted' && current == newGeneration) return;
      if (state == 'deleting' && current == newGeneration) {
        // Resume an interrupted deletion.
      } else {
        if (current != expectedGeneration) {
          throw StateError(
            'Cloud generation mismatch during deletion: '
            'expected=$expectedGeneration actual=$current.',
          );
        }
        if (newGeneration <= expectedGeneration) {
          throw StateError('New cloud generation must be greater.');
        }
        await _firebase.firestore.runTransaction((transaction) async {
          final snap = await transaction.get(rootRef);
          final data = snap.data() ?? const <String, dynamic>{};
          final current =
              (data['cloudGeneration'] as num?)?.toInt() ?? expectedGeneration;
          final state = data['datasetState'] as String? ?? 'empty';
          if (state == 'deleted' && current == newGeneration) return;
          if (current != expectedGeneration ||
              (state != 'empty' &&
                  state != 'ready' &&
                  state != 'initializing')) {
            throw StateError('Cloud dataset changed before deletion.');
          }
          transaction.set(
            rootRef,
            {
              'schemaVersion': cloudSchemaVersion,
              'cloudGeneration': newGeneration,
              'datasetState': 'deleting',
              'updatedAt': FieldValue.serverTimestamp(),
              'bootstrapComplete': false,
            },
            SetOptions(merge: true),
          );
        });
      }
    } else {
      await rootRef.set({
        'schemaVersion': cloudSchemaVersion,
        'cloudGeneration': newGeneration,
        'datasetState': 'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
        'bootstrapComplete': true,
      });
      return;
    }

    await _deleteCollection(uid, 'qazaRecords');
    await _deleteCollection(uid, 'qazaRecordTombstones');
    await _deleteCollection(uid, 'qazaAdditions');
    await _deleteCollection(uid, 'qazaPlanRevisions');

    final actions = await _readDocs(uid, 'deletionActions');
    for (final action in actions) {
      final actionRef = rootRef.collection('deletionActions').doc(action.id);
      final snapshotRef = actionRef.collection('snapshots');
      DocumentSnapshot<Map<String, dynamic>>? snapshotCursor;
      while (true) {
        Query<Map<String, dynamic>> query = snapshotRef.limit(400);
        if (snapshotCursor != null) {
          query = query.startAfterDocument(snapshotCursor);
        }
        final snapshots = await query.get();
        if (snapshots.docs.isEmpty) break;
        final batch = _firebase.firestore.batch();
        for (final doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshots.docs.length < 400) break;
        snapshotCursor = snapshots.docs.last;
      }
      await actionRef.delete();
    }

    await _firebase.firestore.runTransaction((transaction) async {
      final snap = await transaction.get(rootRef);
      if (!snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final current =
          (data['cloudGeneration'] as num?)?.toInt() ?? expectedGeneration;
      if (current != newGeneration) {
        throw StateError('Cloud generation changed during deletion.');
      }
      transaction.set(
        rootRef,
        {
          'schemaVersion': cloudSchemaVersion,
          'cloudGeneration': newGeneration,
          'datasetState': 'deleted',
          'updatedAt': FieldValue.serverTimestamp(),
          'bootstrapComplete': true,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> startNewCloudGeneration({
    required String uid,
    required int previousGeneration,
    required int newGeneration,
  }) async {
    if (!await _firebase.initialize()) {
      throw StateError('Firebase is unavailable.');
    }
    if (newGeneration <= previousGeneration) {
      throw StateError('New cloud generation must be greater.');
    }
    final ref = _firebase.firestore.collection('users').doc(uid);
    await _firebase.firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        transaction.set(
          ref,
          {
            'schemaVersion': cloudSchemaVersion,
            'cloudGeneration': newGeneration,
            'datasetState': 'initializing',
            'updatedAt': FieldValue.serverTimestamp(),
            'bootstrapComplete': false,
          },
        );
        return;
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final current =
          (data['cloudGeneration'] as num?)?.toInt() ?? previousGeneration;
      final state = data['datasetState'] as String? ?? 'empty';
      if (state != 'deleted' || current != previousGeneration) {
        throw StateError('Cloud dataset is not ready for re-enablement.');
      }
      transaction.set(
        ref,
        {
          'schemaVersion': cloudSchemaVersion,
          'cloudGeneration': newGeneration,
          'datasetState': 'initializing',
          'updatedAt': FieldValue.serverTimestamp(),
          'bootstrapComplete': false,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<bool> _hasOutboxMutationAfter(
    String localAccountId,
    int cutoffMicros,
  ) async {
    final rows = await _database.customSelect(
      '''SELECT id FROM sync_outbox
         WHERE user_id = ?
           AND type = 'account_snapshot'
           AND queued_at > ?
         LIMIT 1''',
      variables: [Variable(localAccountId), Variable(cutoffMicros)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _readDocs(
    String uid,
    String collection,
  ) async {
    final ref = _firebase.firestore
        .collection('users')
        .doc(uid)
        .collection(collection);
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = ref.limit(400);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final page = await query.get();
      if (page.docs.isEmpty) break;
      result.addAll(page.docs);
      if (page.docs.length < 400) break;
      cursor = page.docs.last;
    }
    return result;
  }

  Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var start = 0; start < values.length; start += size) {
      final end = (start + size < values.length) ? start + size : values.length;
      yield values.sublist(start, end);
    }
  }

  Future<void> _deleteCollection(String uid, String collection) async {
    final ref = _firebase.firestore
        .collection('users')
        .doc(uid)
        .collection(collection);
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = ref.limit(400);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final page = await query.get();
      if (page.docs.isEmpty) break;

      final batch = _firebase.firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (page.docs.length < 400) break;
      cursor = page.docs.last;
    }
  }

  Future<void> _ensureCloudGeneration({
    required String uid,
    required int expectedGeneration,
    required bool allowCreate,
  }) async {
    final ref = _firebase.firestore.collection('users').doc(uid);
    await _firebase.firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        if (!allowCreate) throw StateError('Cloud account does not exist.');
        transaction.set(ref, {
          'schemaVersion': cloudSchemaVersion,
          'cloudGeneration': expectedGeneration,
          'datasetState': 'initializing',
          'updatedAt': FieldValue.serverTimestamp(),
          'bootstrapComplete': false,
        });
        return;
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final actual = (data['cloudGeneration'] as num?)?.toInt() ?? 1;
      if (actual != expectedGeneration) {
        throw StateError(
          'Cloud generation mismatch: expected=$expectedGeneration actual=$actual.',
        );
      }
      final state = data['datasetState'] as String? ?? 'empty';
      if (state == 'deleted' || state == 'deleting') {
        throw StateError('Cloud dataset state is $state.');
      }
    });
  }

  Future<void> _writeProfile(String localId, String uid, int generation) async {
    final rows = await _database.customSelect(
      '''SELECT payload_json, entity_version, updated_at,
                writer_device_id, operation_id
         FROM account_profiles WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localId)],
    ).get();
    if (rows.isEmpty) return;
    final row = rows.first;
    final payload = _decodeObject(row.read<String>('payload_json'));
    await _writeVersioned(
      _firebase.firestore.collection('users').doc(uid)
          .collection('profile').doc('current'),
      uid: uid,
      payload: {'profile': payload},
      version: VersionedEntity(
        entityVersion: row.read<int>('entity_version'),
        updatedAt: _microsToDate(row.read<int>('updated_at')),
        writerDeviceId: row.read<String>('writer_device_id'),
        operationId: row.read<String>('operation_id'),
        entityId: localId,
      ),
      generation: generation,
      immutable: false,
    );
  }

  Future<void> _writeQazaRecords(
    String localId,
    String uid,
    int generation,
  ) async {
    final rows = await _database.qazaRecordsDao.getAll(userId: localId);
    final device = await _accountStore.deviceInstanceId();
    for (final record in rows) {
      final meta = await _metadata(localId, 'qazaRecord', record.id);
      await _writeVersioned(
        _firebase.firestore.collection('users').doc(uid)
            .collection('qazaRecords').doc(record.id),
        payload: _qazaRecordPayload(record),
        version: meta ??
            VersionedEntity(
              entityVersion: record.recordVersion,
              updatedAt: record.updatedAt,
              writerDeviceId: device,
              operationId:
                  'local_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
              entityId: record.id,
            ),
        uid: uid,
        generation: generation,
        immutable: false,
      );
    }
  }

  Future<void> _writeQazaAdditions(
    String localId,
    String uid,
    int generation,
  ) async {
    final rows = await _database.customSelect(
      '''SELECT id, mode, input_snapshot, revision, created_at, updated_at
         FROM qaza_additions WHERE user_id = ? ORDER BY created_at ASC''',
      variables: [Variable(localId)],
    ).get();
    final device = await _accountStore.deviceInstanceId();
    for (final row in rows) {
      final id = row.read<String>('id');
      final updatedAt = DateTime.parse(row.read<String>('updated_at'));
      final meta = await _metadata(localId, 'qazaAddition', id);
      await _writeVersioned(
        _firebase.firestore.collection('users').doc(uid)
            .collection('qazaAdditions').doc(id),
        payload: {
          'id': id,
          'mode': row.read<String>('mode'),
          'currentInputSnapshot':
              _decodeObject(row.read<String>('input_snapshot')),
          'revision': row.read<int>('revision'),
          'createdAt': DateTime.parse(row.read<String>('created_at')),
          'updatedAt': updatedAt,
        },
        version: meta ??
            VersionedEntity(
              entityVersion: row.read<int>('revision'),
              updatedAt: updatedAt,
              writerDeviceId: device,
              operationId:
                  'addition_${id}_${row.read<int>('revision')}',
              entityId: id,
            ),
        uid: uid,
        generation: generation,
        immutable: false,
      );
    }
  }

  Future<void> _writeDeletionActions(
    String localId,
    String uid,
    int generation,
  ) async {
    final actions = await _database.customSelect(
      '''SELECT id, addition_id, created_at, resolved_at
         FROM qaza_deletion_actions WHERE user_id = ? ORDER BY created_at ASC''',
      variables: [Variable(localId)],
    ).get();
    final device = await _accountStore.deviceInstanceId();

    for (final row in actions) {
      final actionId = row.read<String>('id');
      final createdAt = DateTime.parse(row.read<String>('created_at'));
      final resolvedRaw = row.read<String?>('resolved_at');
      final updatedAt =
          resolvedRaw == null ? createdAt : DateTime.parse(resolvedRaw);
      await _writeVersioned(
        _firebase.firestore.collection('users').doc(uid)
            .collection('deletionActions').doc(actionId),
        payload: {
          'id': actionId,
          'additionId': row.read<String>('addition_id'),
          'createdAt': createdAt,
          'resolvedAt':
              resolvedRaw == null ? null : DateTime.parse(resolvedRaw),
        },
        version: await _metadata(localId, 'deletionAction', actionId) ??
            VersionedEntity(
              entityVersion: 1,
              updatedAt: updatedAt,
              writerDeviceId: device,
              operationId: 'deletion_${actionId}',
              entityId: actionId,
            ),
        uid: uid,
        generation: generation,
        immutable: false,
      );

      final snapshots = await _database.customSelect(
        '''SELECT deletion_action_id, record_id, user_id, addition_id,
                  prayer_type, original_date, status, completed_at,
                  completion_id, created_at, updated_at, record_version
           FROM qaza_deletion_action_record_snapshots
           WHERE deletion_action_id = ? AND user_id = ?''',
        variables: [Variable(actionId), Variable(localId)],
      ).get();
      for (final snapshot in snapshots) {
        final id = snapshot.read<String>('record_id');
        final payload = <String, dynamic>{
          'deletionActionId': actionId,
          'recordId': id,
          'additionId': snapshot.read<String>('addition_id'),
          'prayerType': snapshot.read<String>('prayer_type'),
          'originalDate':
              DateTime.parse(snapshot.read<String>('original_date')),
          'status': snapshot.read<String>('status'),
          'completedAt':
              _parseDate(snapshot.read<String?>('completed_at')),
          'completionId': snapshot.read<String?>('completion_id'),
          'createdAt': DateTime.parse(snapshot.read<String>('created_at')),
          'updatedAt': DateTime.parse(snapshot.read<String>('updated_at')),
          'recordVersion': snapshot.read<int>('record_version'),
        };
        await _writeVersioned(
          _firebase.firestore.collection('users').doc(uid)
              .collection('deletionActions').doc(actionId)
              .collection('snapshots').doc(id),
          payload: payload,
          version: VersionedEntity(
            entityVersion: snapshot.read<int>('record_version'),
            updatedAt:
                DateTime.parse(snapshot.read<String>('updated_at')),
            writerDeviceId: device,
            operationId: 'snapshot_${actionId}_${id}',
            entityId: id,
          ),
          uid: uid,
          generation: generation,
          immutable: true,
        );
      }
    }
  }

  Future<void> _writePlanRevisions(
    String localId,
    String uid,
    int generation,
  ) async {
    final revisions = await _accountStore.loadPlanRevisions(localId);
    final device = await _accountStore.deviceInstanceId();
    for (final revision in revisions) {
      await _writeVersioned(
        _firebase.firestore.collection('users').doc(uid)
            .collection('qazaPlanRevisions').doc(revision.revisionId),
        payload: revision.toJson(),
        version: VersionedEntity(
          entityVersion: 1,
          updatedAt: revision.createdAt,
          writerDeviceId: device,
          operationId: 'plan_${revision.revisionId}',
          entityId: revision.revisionId,
        ),
        uid: uid,
        generation: generation,
        immutable: true,
      );
    }
  }

  Future<void> _writeTombstones(
    String localId,
    String uid,
    int generation,
  ) async {
    final rows = await _database.customSelect(
      '''SELECT record_id, record_version, deleted_at, writer_device_id,
                operation_id, cloud_generation
         FROM qaza_record_tombstones WHERE local_account_id = ?''',
      variables: [Variable(localId)],
    ).get();
    final ref = _firebase.firestore.collection('users').doc(uid)
        .collection('qazaRecordTombstones');

    for (final row in rows) {
      final id = row.read<String>('record_id');
      final version = row.read<int>('record_version');
      await _writeVersioned(
        ref.doc(id),
        payload: {
          'recordId': id,
          'recordVersion': version,
          'deletedAt': _microsToDate(row.read<int>('deleted_at')),
          'cloudGeneration': row.read<int>('cloud_generation'),
        },
        version: VersionedEntity(
          entityVersion: version,
          updatedAt: _microsToDate(row.read<int>('deleted_at')),
          writerDeviceId: row.read<String>('writer_device_id'),
          operationId: row.read<String>('operation_id'),
          entityId: id,
        ),
        uid: uid,
        generation: generation,
        immutable: false,
      );

      final recordRef = _firebase.firestore.collection('users').doc(uid)
          .collection('qazaRecords').doc(id);
      await _firebase.firestore.runTransaction((transaction) async {
        final recordSnap = await transaction.get(recordRef);
        if (!recordSnap.exists) return;
        final recordData = recordSnap.data() ?? const <String, dynamic>{};
        final recordVersion =
            (recordData['recordVersion'] as num?)?.toInt() ?? 0;
        if (version >= recordVersion) {
          transaction.delete(recordRef);
        }
      });
    }
  }

  Future<VersionedEntity?> _metadata(
    String localId,
    String type,
    String entityId,
  ) async {
    final rows = await _database.customSelect(
      '''SELECT entity_version, updated_at, writer_device_id, operation_id
         FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = ? AND entity_id = ?
         LIMIT 1''',
      variables: [Variable(localId), Variable(type), Variable(entityId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return VersionedEntity(
      entityVersion: row.read<int>('entity_version'),
      updatedAt: _microsToDate(row.read<int>('updated_at')),
      writerDeviceId: row.read<String>('writer_device_id'),
      operationId: row.read<String>('operation_id'),
      entityId: entityId,
    );
  }

  Future<void> _writeVersioned(
    DocumentReference<Map<String, dynamic>> ref, {
    required String uid,
    required Map<String, dynamic> payload,
    required VersionedEntity version,
    required int generation,
    required bool immutable,
  }) async {
    final rootRef =
        _firebase.firestore.collection('users').doc(uid);
    await _firebase.firestore.runTransaction((transaction) async {
      // Read the generation anchor and the entity in the same transaction.
      // This prevents a concurrent cloud deletion from racing a stale
      // snapshot write and recreating data under an old generation.
      final rootSnapshot = await transaction.get(rootRef);
      if (!rootSnapshot.exists) {
        throw StateError(
          'Cloud account root is missing while writing ' + ref.path,
        );
      }
      final rootData =
          rootSnapshot.data() ?? const <String, dynamic>{};
      final rootGeneration =
          (rootData['cloudGeneration'] as num?)?.toInt() ?? 0;
      final rootState = rootData['datasetState'] as String? ?? 'empty';
      if (rootGeneration != generation ||
          (rootState != 'initializing' && rootState != 'ready')) {
        throw StateError(
          'Cloud generation/state changed while writing ' +
              ref.path +
              ': generation=' +
              rootGeneration.toString() +
              ' state=' +
              rootState,
        );
      }

      final current = await transaction.get(ref);
      final currentData = current.data();
      if (currentData != null) {
        final remote = VersionedEntity(
          entityVersion:
              (currentData['entityVersion'] as num?)?.toInt() ?? 0,
          updatedAt: _timestampDate(currentData['updatedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          writerDeviceId: currentData['writerDeviceId'] as String? ?? '',
          operationId: currentData['operationId'] as String? ?? '',
          entityId: ref.id,
        );
        final cmp = _resolver.compare(version, remote);
        if (cmp < 0) return;

        if (immutable &&
            cmp == 0 &&
            jsonEncode(currentData['payload']) != jsonEncode(payload)) {
          throw StateError(
            'Immutable cloud entity conflict: ' + ref.path,
          );
        }
        final remoteGeneration =
            (currentData['cloudGeneration'] as num?)?.toInt();
        if (remoteGeneration != null && remoteGeneration != generation) {
          throw StateError(
            'Cloud generation changed while writing ' + ref.path + '.',
          );
        }
      }

      transaction.set(
        ref,
        {
          'schemaVersion': cloudSchemaVersion,
          'cloudGeneration': generation,
          'entityVersion': version.entityVersion,
          'updatedAt': Timestamp.fromDate(version.updatedAt),
          'writerDeviceId': version.writerDeviceId,
          'operationId': version.operationId,
          'payload': payload,
          'immutable': immutable,
        },
        SetOptions(merge: true),
      );
    });
  }

  Map<String, dynamic> _qazaRecordPayload(QazaRecord record) => {
        'id': record.id,
        'prayerType': record.prayerType.name,
        'originalDate': record.originalDate,
        'status': record.status.name,
        'completedAt': record.completedAt,
        'completionId': record.completionId,
        'additionId': record.additionId,
        'profilePlanRevisionId': record.profilePlanRevisionId,
        'profilePlanFingerprint': record.profilePlanFingerprint,
        'recordVersion': record.recordVersion,
        'createdAt': record.createdAt,
        'updatedAt': record.updatedAt,
      };

  Map<String, dynamic> _decodeObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  DateTime? _parseDate(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw);

  DateTime _microsToDate(int micros) =>
      DateTime.fromMicrosecondsSinceEpoch(micros);

  DateTime? _timestampDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
