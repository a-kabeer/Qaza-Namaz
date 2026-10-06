
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Variable;

import '../../domain/entities/qaza_record.dart';
import '../../domain/services/conflict_resolver.dart';
import '../local/account_local_store.dart';
import '../local/database/app_database.dart';
import 'firebase_services.dart';
import 'backup_failure.dart';

typedef BackupProgressCallback = FutureOr<void> Function(
  int processed,
  int total,
);

class _BackupProgressReporter {
  _BackupProgressReporter({
    required int total,
    this.onProgress,
  }) : total = total > 0 ? total : 1;

  int processed = 0;
  int total;
  final BackupProgressCallback? onProgress;

  Future<void> start() async {
    await _emit();
  }

  Future<void> add(int units) async {
    if (units <= 0) return;
    processed += units;
    if (processed > total) {
      total = processed;
    }
    await _emit();
  }

  Future<void> _emit() async {
    final callback = onProgress;
    if (callback != null) {
      await callback(processed, total);
    }
  }
}

class _VersionedWrite {
  const _VersionedWrite({
    required this.ref,
    required this.payload,
    required this.version,
    required this.immutable,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> payload;
  final VersionedEntity version;
  final bool immutable;
}

enum CloudRootStatus {
  missing,
  exists,
  unavailable,
}

class CloudRootReadResult {
  const CloudRootReadResult({
    required this.status,
    this.data,
    this.failure,
  });

  final CloudRootStatus status;
  final Map<String, dynamic>? data;
  final BackupFailure? failure;

  bool get isAvailable => status != CloudRootStatus.unavailable;
  bool get exists => status == CloudRootStatus.exists;
}


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

  Future<void> _ensureAuthenticatedUid(String uid) async {
    final user = _firebase.auth.currentUser;
    if (user == null) {
      throw const BackupFailure(
        category: BackupFailureCategory.authenticationUnavailable,
        message: 'Firebase authentication session is unavailable.',
      );
    }
    if (user.uid != uid) {
      throw const BackupFailure(
        category: BackupFailureCategory.authenticationUidMismatch,
        message: 'Firebase authentication UID does not match the backup account.',
      );
    }
  }

  Future<CloudRootReadResult> readCloudRootResult(String uid) async {
    try {
      await _firebase.ensureFirestoreReady();
      await _ensureAuthenticatedUid(uid);
      final snap = await _firebase.firestore.collection('users').doc(uid).get();
      if (!snap.exists) {
        return const CloudRootReadResult(status: CloudRootStatus.missing);
      }
      return CloudRootReadResult(
        status: CloudRootStatus.exists,
        data: snap.data(),
      );
    } catch (error, stack) {
      final failure = classifyBackupFailure(error, stackTrace: stack);
      return CloudRootReadResult(
        status: CloudRootStatus.unavailable,
        failure: failure,
      );
    }
  }

  @Deprecated('Use readCloudRootResult to distinguish missing from failure.')
  Future<Map<String, dynamic>?> readCloudRoot(String uid) async {
    final result = await readCloudRootResult(uid);
    if (!result.isAvailable) {
      throw result.failure ??
          const BackupFailure(
            category: BackupFailureCategory.unknown,
            message: 'Cloud root could not be read.',
          );
    }
    return result.data;
  }

  Future<void> bootstrapAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    BackupProgressCallback? onProgress,
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
      onProgress: onProgress,
    );
  }

  Future<void> snapshotAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    int? bootstrapCutoffMicros,
    BackupProgressCallback? onProgress,
  }) async {
    await _firebase.ensureFirestoreReady();
    await _ensureAuthenticatedUid(uid);

    final incremental = bootstrapCutoffMicros == null;
    final progress = _BackupProgressReporter(
      total: await _calculateBackupWorkTotal(
        localAccountId,
        incremental: incremental,
      ),
      onProgress: onProgress,
    );
    await progress.start();

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
      // A root can be recreated only after a successful Firestore read proved
      // that the document is genuinely missing. Initialization/auth/App Check
      // failures never reach this branch.
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

    await _writeProfile(
      localAccountId,
      uid,
      generation,
      onProgress: progress.add,
    );
    await _writeQazaRecords(
      localAccountId,
      uid,
      generation,
      incremental: incremental,
      onProgress: progress.add,
    );
    await _writeQazaAdditions(
      localAccountId,
      uid,
      generation,
      onProgress: progress.add,
    );
    await _writeDeletionActions(
      localAccountId,
      uid,
      generation,
      onProgress: progress.add,
    );
    await _writePlanRevisions(
      localAccountId,
      uid,
      generation,
      onProgress: progress.add,
    );
    await _writeTombstones(
      localAccountId,
      uid,
      generation,
      incremental: incremental,
      onProgress: progress.add,
    );

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

    // Finalization is the last real unit of backup work. Report 100% only
    // after the cloud root has been atomically marked ready.
    await progress.add(1);
  }


  Future<void> deleteCloudData({
    required String uid,
    required int expectedGeneration,
    required int newGeneration,
  }) async {
    await _firebase.ensureFirestoreReady();
    await _ensureAuthenticatedUid(uid);

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
    await _firebase.ensureFirestoreReady();
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
    await _firebase.ensureFirestoreReady();
    await _ensureAuthenticatedUid(uid);
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

  Future<int> _calculateBackupWorkTotal(
    String localId, {
    required bool incremental,
  }) async {
    final profile = await _countLocalRows(
      'SELECT COUNT(*) AS count FROM account_profiles '
      'WHERE local_account_id = ?',
      localId,
    );

    final qazaRecords = incremental
        ? await _countLocalRows(
            '''SELECT COUNT(*) AS count
               FROM qaza_records r
               LEFT JOIN entity_metadata m
                 ON m.local_account_id = r.user_id
                AND m.entity_type = 'qazaRecord'
                AND m.entity_id = r.id
               WHERE r.user_id = ?
                 AND (
                   m.entity_id IS NULL
                   OR m.synced_entity_version < m.entity_version
                 )''',
            localId,
          )
        : await _countLocalRows(
            'SELECT COUNT(*) AS count FROM qaza_records WHERE user_id = ?',
            localId,
          );

    final additions = await _countLocalRows(
      'SELECT COUNT(*) AS count FROM qaza_additions WHERE user_id = ?',
      localId,
    );
    final deletionActions = await _countLocalRows(
      'SELECT COUNT(*) AS count FROM qaza_deletion_actions WHERE user_id = ?',
      localId,
    );
    final deletionSnapshots = await _countLocalRows(
      'SELECT COUNT(*) AS count '
      'FROM qaza_deletion_action_record_snapshots WHERE user_id = ?',
      localId,
    );
    final planRevisions = await _countLocalRows(
      'SELECT COUNT(*) AS count '
      'FROM account_plan_revisions WHERE local_account_id = ?',
      localId,
    );

    final tombstones = incremental
        ? await _countLocalRows(
            '''SELECT COUNT(*) AS count
               FROM qaza_record_tombstones t
               LEFT JOIN entity_metadata m
                 ON m.local_account_id = t.local_account_id
                AND m.entity_type = 'qazaRecord'
                AND m.entity_id = t.record_id
               WHERE t.local_account_id = ?
                 AND (
                   m.entity_id IS NULL
                   OR m.synced_entity_version < m.entity_version
                 )''',
            localId,
          )
        : await _countLocalRows(
            'SELECT COUNT(*) AS count '
            'FROM qaza_record_tombstones WHERE local_account_id = ?',
            localId,
          );

    // One additional unit represents the final cloud-root finalization.
    return profile +
        qazaRecords +
        additions +
        deletionActions +
        deletionSnapshots +
        planRevisions +
        tombstones +
        1;
  }

  Future<int> _countLocalRows(String sql, String localId) async {
    final rows = await _database.customSelect(
      sql,
      variables: [Variable(localId)],
    ).get();
    return rows.isEmpty ? 0 : rows.single.read<int>('count');
  }

  Future<void> _writeProfile(
    String localId,
    String uid,
    int generation, {
    Future<void> Function(int units)? onProgress,
  }) async {
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
    if (onProgress != null) {
      await onProgress(1);
    }
  }

  Future<void> _writeQazaRecords(
    String localId,
    String uid,
    int generation, {
    bool incremental = false,
    Future<void> Function(int units)? onProgress,
  }) async {
    if (!incremental) {
      final rows = await _database.qazaRecordsDao.getAll(userId: localId);
      if (rows.isEmpty) return;
      final metadata = await _metadataByType(localId, 'qazaRecord');
      final device = await _accountStore.deviceInstanceId();
      final writes = <_VersionedWrite>[
        for (final record in rows)
          _VersionedWrite(
            ref: _firebase.firestore.collection('users').doc(uid)
                .collection('qazaRecords').doc(record.id),
            payload: _qazaRecordPayload(record),
            version: metadata[record.id] ??
                VersionedEntity(
                  entityVersion: record.recordVersion,
                  updatedAt: record.updatedAt,
                  writerDeviceId: device,
                  operationId:
                      'local_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
                  entityId: record.id,
                ),
            immutable: false,
            ),
      ];
      await _writeVersionedBatch(
        uid: uid,
        generation: generation,
        writes: writes,
        onProgress: onProgress,
      );
      await _markQazaEntitiesSynced(localId, writes);
      return;
    }

    final rows = await _database.customSelect(
      '''SELECT r.id, r.prayer_type, r.original_date, r.status,
                r.completed_at, r.completion_id, r.addition_id,
                r.record_version, r.created_at, r.updated_at,
                p.plan_revision_id, p.plan_fingerprint,
                m.entity_version, m.updated_at AS meta_updated_at,
                m.writer_device_id, m.operation_id
         FROM qaza_records r
         LEFT JOIN qaza_profile_plan_provenance p
           ON p.user_id = r.user_id
          AND p.record_id = r.id
         LEFT JOIN entity_metadata m
           ON m.local_account_id = r.user_id
          AND m.entity_type = 'qazaRecord'
          AND m.entity_id = r.id
         WHERE r.user_id = ?
           AND (
             m.entity_id IS NULL
             OR m.synced_entity_version < m.entity_version
           )''',
      variables: [Variable(localId)],
    ).get();
    if (rows.isEmpty) return;

    final device = await _accountStore.deviceInstanceId();
    final writes = <_VersionedWrite>[
      for (final row in rows)
        _VersionedWrite(
          ref: _firebase.firestore.collection('users').doc(uid)
              .collection('qazaRecords').doc(row.read<String>('id')),
          payload: {
            'id': row.read<String>('id'),
            'prayerType': row.read<String>('prayer_type'),
            'originalDate': _microsToDate(
              row.read<int>('original_date'),
            ),
            'status': row.read<String>('status'),
            'completedAt': _optionalMicrosToDate(
              row.read<int?>('completed_at'),
            ),
            'completionId': row.read<String?>('completion_id'),
            'additionId': row.read<String?>('addition_id'),
            'profilePlanRevisionId':
                row.read<String?>('plan_revision_id'),
            'profilePlanFingerprint':
                row.read<String?>('plan_fingerprint'),
            'recordVersion': row.read<int>('record_version'),
            'createdAt': _microsToDate(row.read<int>('created_at')),
            'updatedAt': _microsToDate(row.read<int>('updated_at')),
          },
          version: row.read<int?>('entity_version') == null
              ? VersionedEntity(
                  entityVersion: row.read<int>('record_version'),
                  updatedAt: _microsToDate(row.read<int>('updated_at')),
                  writerDeviceId: device,
                  operationId:
                      'local_${row.read<String>('id')}_${row.read<int>('updated_at')}',
                  entityId: row.read<String>('id'),
                )
              : VersionedEntity(
                  entityVersion: row.read<int>('entity_version'),
                  updatedAt: _microsToDate(row.read<int>('meta_updated_at')),
                  writerDeviceId: row.read<String>('writer_device_id'),
                  operationId: row.read<String>('operation_id'),
                  entityId: row.read<String>('id'),
                ),
          immutable: false,
        ),
    ];

    await _writeVersionedBatch(
      uid: uid,
      generation: generation,
      writes: writes,
      onProgress: onProgress,
    );
    await _markQazaEntitiesSynced(localId, writes);
  }

  Future<void> _writeQazaAdditions(
    String localId,
    String uid,
    int generation, {
    Future<void> Function(int units)? onProgress,
  }) async {
    final rows = await _database.customSelect(
      '''SELECT id, mode, input_snapshot, revision, created_at, updated_at
         FROM qaza_additions WHERE user_id = ? ORDER BY created_at ASC''',
      variables: [Variable(localId)],
    ).get();
    if (rows.isEmpty) return;
    final metadata = await _metadataByType(localId, 'qazaAddition');
    final device = await _accountStore.deviceInstanceId();
    final writes = <_VersionedWrite>[];

    for (final row in rows) {
      final id = row.read<String>('id');
      final updatedAt = DateTime.parse(row.read<String>('updated_at'));
      final revision = row.read<int>('revision');
      writes.add(
        _VersionedWrite(
          ref: _firebase.firestore.collection('users').doc(uid)
              .collection('qazaAdditions').doc(id),
          payload: {
            'id': id,
            'mode': row.read<String>('mode'),
            'currentInputSnapshot':
                _decodeObject(row.read<String>('input_snapshot')),
            'revision': revision,
            'createdAt': DateTime.parse(row.read<String>('created_at')),
            'updatedAt': updatedAt,
          },
          version: metadata[id] ??
              VersionedEntity(
                entityVersion: revision,
                updatedAt: updatedAt,
                writerDeviceId: device,
                operationId: 'addition_${id}_${revision}',
                entityId: id,
              ),
          immutable: false,
        ),
      );
    }

    await _writeVersionedBatch(
      uid: uid,
      generation: generation,
      writes: writes,
      onProgress: onProgress,
    );
  }

  Future<void> _writeDeletionActions(
    String localId,
    String uid,
    int generation, {
    Future<void> Function(int units)? onProgress,
  }) async {
    final actions = await _database.customSelect(
      '''SELECT id, addition_id, created_at, resolved_at, entity_version
         FROM qaza_deletion_actions WHERE user_id = ? ORDER BY created_at ASC''',
      variables: [Variable(localId)],
    ).get();
    if (actions.isEmpty) return;

    final metadata = await _metadataByType(localId, 'deletionAction');
    final device = await _accountStore.deviceInstanceId();
    final writes = <_VersionedWrite>[];

    for (final row in actions) {
      final actionId = row.read<String>('id');
      final createdAt = DateTime.parse(row.read<String>('created_at'));
      final resolvedRaw = row.read<String?>('resolved_at');
      final updatedAt =
          resolvedRaw == null ? createdAt : DateTime.parse(resolvedRaw);
      final entityVersion = row.read<int>('entity_version');

      writes.add(
        _VersionedWrite(
          ref: _firebase.firestore.collection('users').doc(uid)
              .collection('deletionActions').doc(actionId),
          payload: {
            'id': actionId,
            'additionId': row.read<String>('addition_id'),
            'createdAt': createdAt,
            'resolvedAt':
                resolvedRaw == null ? null : DateTime.parse(resolvedRaw),
          },
          version: metadata[actionId] ??
              VersionedEntity(
                entityVersion: entityVersion,
                updatedAt: updatedAt,
                writerDeviceId: device,
                operationId: 'deletion_${actionId}',
                entityId: actionId,
              ),
          immutable: false,
        ),
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
        writes.add(
          _VersionedWrite(
            ref: _firebase.firestore.collection('users').doc(uid)
                .collection('deletionActions').doc(actionId)
                .collection('snapshots').doc(id),
            payload: {
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
            },
            version: VersionedEntity(
              entityVersion: snapshot.read<int>('record_version'),
              updatedAt:
                  DateTime.parse(snapshot.read<String>('updated_at')),
              writerDeviceId: device,
              operationId: 'snapshot_${actionId}_${id}',
              entityId: id,
            ),
              immutable: true,
          ),
        );
      }
    }

    await _writeVersionedBatch(
      uid: uid,
      generation: generation,
      writes: writes,
      onProgress: onProgress,
    );
  }

  Future<void> _writePlanRevisions(
    String localId,
    String uid,
    int generation, {
    Future<void> Function(int units)? onProgress,
  }) async {
    final revisions = await _accountStore.loadPlanRevisions(localId);
    if (revisions.isEmpty) return;
    final device = await _accountStore.deviceInstanceId();
    final writes = <_VersionedWrite>[
      for (final revision in revisions)
        _VersionedWrite(
          ref: _firebase.firestore.collection('users').doc(uid)
              .collection('qazaPlanRevisions').doc(revision.revisionId),
          payload: revision.toJson(),
          version: VersionedEntity(
            entityVersion: 1,
            updatedAt: revision.createdAt,
            writerDeviceId: device,
            operationId: 'plan_${revision.revisionId}',
            entityId: revision.revisionId,
          ),
          immutable: true,
        ),
    ];
    await _writeVersionedBatch(
      uid: uid,
      generation: generation,
      writes: writes,
      onProgress: onProgress,
    );
  }

  Future<void> _writeTombstones(
    String localId,
    String uid,
    int generation, {
    bool incremental = false,
    Future<void> Function(int units)? onProgress,
  }) async {
    final where = incremental
        ? '''AND (
             m.entity_id IS NULL
             OR m.synced_entity_version < m.entity_version
           )'''
        : '';
    final rows = await _database.customSelect(
      '''SELECT t.record_id, t.record_version, t.deleted_at, t.writer_device_id,
                t.operation_id, t.cloud_generation,
                m.entity_version AS meta_entity_version
         FROM qaza_record_tombstones t
         LEFT JOIN entity_metadata m
           ON m.local_account_id = t.local_account_id
          AND m.entity_type = 'qazaRecord'
          AND m.entity_id = t.record_id
         WHERE t.local_account_id = ? $where''',
      variables: [Variable(localId)],
    ).get();
    if (rows.isEmpty) return;

    final writes = <_VersionedWrite>[
      for (final row in rows)
        _VersionedWrite(
          ref: _firebase.firestore.collection('users').doc(uid)
              .collection('qazaRecordTombstones')
              .doc(row.read<String>('record_id')),
          payload: {
            'recordId': row.read<String>('record_id'),
            'recordVersion': row.read<int>('record_version'),
            'deletedAt': _microsToDate(row.read<int>('deleted_at')),
            'cloudGeneration': row.read<int>('cloud_generation'),
          },
          version: VersionedEntity(
            entityVersion:
                row.read<int?>('meta_entity_version') ??
                row.read<int>('record_version'),
            updatedAt: _microsToDate(row.read<int>('deleted_at')),
            writerDeviceId: row.read<String>('writer_device_id'),
            operationId: row.read<String>('operation_id'),
            entityId: row.read<String>('record_id'),
          ),
          immutable: false,
        ),
    ];

    await _writeVersionedBatch(
      uid: uid,
      generation: generation,
      writes: writes,
      onProgress: onProgress,
    );
    await _deleteRecordsCoveredByCloudTombstones(
      uid: uid,
      generation: generation,
      recordIds: rows
          .map((row) => row.read<String>('record_id'))
          .toList(growable: false),
    );
    await _markQazaEntitiesSynced(localId, writes);
  }

  Future<void> _markQazaEntitiesSynced(
    String localId,
    List<_VersionedWrite> writes,
  ) async {
    if (writes.isEmpty) return;
    await _database.transaction(() async {
      for (final operation in writes) {
        await _database.customUpdate(
          '''UPDATE entity_metadata
             SET synced_entity_version = ?
             WHERE local_account_id = ?
               AND entity_type = 'qazaRecord'
               AND entity_id = ?
               AND entity_version = ?''',
          variables: [
            Variable(operation.version.entityVersion),
            Variable(localId),
            Variable(operation.version.entityId),
            Variable(operation.version.entityVersion),
          ],
        );
      }
    });
  }

  DateTime? _optionalMicrosToDate(int? micros) =>
      micros == null ? null : _microsToDate(micros);

  Future<void> _deleteRecordsCoveredByCloudTombstones({
    required String uid,
    required int generation,
    required List<String> recordIds,
  }) async {
    final rootRef = _firebase.firestore.collection('users').doc(uid);
    final tombstoneRef = rootRef.collection('qazaRecordTombstones');
    final recordRef = rootRef.collection('qazaRecords');

    for (final ids in _chunks(recordIds, 10)) {
      await _firebase.firestore.runTransaction((transaction) async {
        final rootSnapshot = await transaction.get(rootRef);
        _assertCloudRootForWrite(
          snapshot: rootSnapshot,
          generation: generation,
          context: 'tombstone cleanup',
        );

        final tombstones =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        final records = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final id in ids) {
          tombstones[id] = await transaction.get(tombstoneRef.doc(id));
          records[id] = await transaction.get(recordRef.doc(id));
        }

        for (final id in ids) {
          final tombstone = tombstones[id];
          final record = records[id];
          if (tombstone == null ||
              !tombstone.exists ||
              record == null ||
              !record.exists) {
            continue;
          }

          final tombstoneData =
              tombstone.data() ?? const <String, dynamic>{};
          final recordData = record.data() ?? const <String, dynamic>{};
          final payload = tombstoneData['payload'];
          if (payload is! Map) continue;

          final tombstoneGeneration =
              (payload['cloudGeneration'] as num?)?.toInt() ?? 0;
          if (tombstoneGeneration != generation) continue;

          final tombstoneVersion =
              (payload['recordVersion'] as num?)?.toInt() ?? 0;
          final recordPayload = recordData['payload'];
          final recordVersion = recordPayload is Map
              ? (recordPayload['recordVersion'] as num?)?.toInt() ?? 0
              : 0;

          if (tombstoneVersion >= recordVersion) {
            transaction.delete(recordRef.doc(id));
          }
        }
      });
    }
  }

  Future<Map<String, VersionedEntity>> _metadataByType(
    String localId,
    String type,
  ) async {
    final rows = await _database.customSelect(
      '''SELECT entity_id, entity_version, updated_at, writer_device_id,
                operation_id
         FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = ?''',
      variables: [Variable(localId), Variable(type)],
    ).get();
    return <String, VersionedEntity>{
      for (final row in rows)
        row.read<String>('entity_id'): VersionedEntity(
          entityVersion: row.read<int>('entity_version'),
          updatedAt: _microsToDate(row.read<int>('updated_at')),
          writerDeviceId: row.read<String>('writer_device_id'),
          operationId: row.read<String>('operation_id'),
          entityId: row.read<String>('entity_id'),
        ),
    };
  }

  Future<void> _writeVersionedBatch({
    required String uid,
    required int generation,
    required List<_VersionedWrite> writes,
    Future<void> Function(int units)? onProgress,
  }) async {
    if (writes.isEmpty) return;
    final rootRef = _firebase.firestore.collection('users').doc(uid);

    // Keep backup transactions well below the 500-write ceiling. The smaller
    // chunk also leaves headroom for transaction/rules/request-size overhead
    // and avoids making a single transient Firestore failure discard a large
    // portion of an account snapshot.
    for (final chunk in _chunks(writes, 100)) {
      await _firebase.firestore.runTransaction((transaction) async {
        final rootSnapshot = await transaction.get(rootRef);
        _assertCloudRootForWrite(
          snapshot: rootSnapshot,
          generation: generation,
          context: 'batched backup',
        );

        final current = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final operation in chunk) {
          current[operation.ref.path] = await transaction.get(operation.ref);
        }

        for (final operation in chunk) {
          final snapshot = current[operation.ref.path];
          final currentData = snapshot?.data();
          if (currentData != null) {
            final remote = VersionedEntity(
              entityVersion:
                  (currentData['entityVersion'] as num?)?.toInt() ?? 0,
              updatedAt: _timestampDate(currentData['updatedAt']) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              writerDeviceId: currentData['writerDeviceId'] as String? ?? '',
              operationId: currentData['operationId'] as String? ?? '',
              entityId: operation.ref.id,
            );
            final cmp = _resolver.compare(operation.version, remote);
            if (cmp < 0) continue;
            if (cmp == 0) {
              if (!operation.immutable) continue;
              final remotePayload = currentData['payload'];
              if (jsonEncode(remotePayload) == jsonEncode(operation.payload)) {
                continue;
              }
              throw StateError(
                'Immutable cloud entity conflict: ' + operation.ref.path,
              );
            }

            if (operation.immutable) {
              throw StateError(
                'Immutable cloud entity conflict: ' + operation.ref.path,
              );
            }

            final remoteGeneration =
                (currentData['cloudGeneration'] as num?)?.toInt();
            if (remoteGeneration != null &&
                remoteGeneration != generation) {
              throw StateError(
                'Cloud generation changed while writing ' +
                    operation.ref.path +
                    '.',
              );
            }
          }
        }

        for (final operation in chunk) {
          final snapshot = current[operation.ref.path];
          final currentData = snapshot?.data();
          if (currentData != null) {
            final remote = VersionedEntity(
              entityVersion:
                  (currentData['entityVersion'] as num?)?.toInt() ?? 0,
              updatedAt: _timestampDate(currentData['updatedAt']) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              writerDeviceId: currentData['writerDeviceId'] as String? ?? '',
              operationId: currentData['operationId'] as String? ?? '',
              entityId: operation.ref.id,
            );
            final cmp = _resolver.compare(operation.version, remote);
            if (cmp <= 0) continue;
          }

          transaction.set(
            operation.ref,
            {
              'schemaVersion': cloudSchemaVersion,
              'cloudGeneration': generation,
              'entityVersion': operation.version.entityVersion,
              'updatedAt': Timestamp.fromDate(operation.version.updatedAt),
              'writerDeviceId': operation.version.writerDeviceId,
              'operationId': operation.version.operationId,
              'payload': operation.payload,
              'immutable': operation.immutable,
            },
            SetOptions(merge: true),
          );
        }
      });
      if (onProgress != null) {
        await onProgress(chunk.length);
      }
    }
  }

  void _assertCloudRootForWrite({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required int generation,
    required String context,
  }) {
    if (!snapshot.exists) {
      throw StateError(
        'Cloud account root is missing during ' + context + '.',
      );
    }
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rootGeneration =
        (data['cloudGeneration'] as num?)?.toInt() ?? 0;
    final rootState = data['datasetState'] as String? ?? 'empty';
    if (rootGeneration != generation ||
        (rootState != 'initializing' && rootState != 'ready')) {
      throw StateError(
        'Cloud generation/state changed during ' +
            context +
            ': generation=' +
            rootGeneration.toString() +
            ' state=' +
            rootState,
      );
    }
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

        if (immutable) {
          if (cmp == 0 &&
              jsonEncode(currentData['payload']) == jsonEncode(payload)) {
            // Immutable entities are write-once. A retry of the same
            // snapshot/revision must be a no-op, because Firestore rules
            // intentionally reject updates to immutable documents.
            return;
          }
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
