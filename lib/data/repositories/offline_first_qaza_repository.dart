import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_activity.dart';
import '../../domain/repositories/qaza_activity_repository.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/repositories/qaza_profile_plan_mutation_repository.dart';
import '../../domain/repositories/qaza_bulk_write_repository.dart';
import '../../domain/repositories/qaza_undo_repository.dart';
import '../local/qaza_local_store.dart';

/// Local-only Qaza repository.
///
/// Account authentication, Google Sign-In, Firebase Authentication, Firestore
/// synchronization, and guest-to-account migration are no longer part of the
/// application. The repository boundary remains so the domain and UI layers
/// stay independent of the local database implementation.
class OfflineFirstQazaRepository
    implements
        QazaRepository,
        QazaProfilePlanMutationRepository,
        QazaBulkWriteRepository,
        QazaUndoRepository,
        QazaActivityRepository {
  OfflineFirstQazaRepository({
    required QazaLocalStore localStore,
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  })  : _localStore = localStore,
        _diagnostics = diagnostics;

  final QazaLocalStore _localStore;
  final DiagnosticsService _diagnostics;
  String? _activeUserId;

  String? get activeUserId => _activeUserId;

  Future<void> setActiveUser(String? userId) async {
    _activeUserId = userId;
  }

  /// Kept as a compatibility no-op for callers/tests written against the old
  /// offline-first implementation. There is no remote hydration anymore.
  Future<void> ensureHydrated() async {}

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    _validateActive(userId);
    final records = <QazaRecord>[];
    DateTime? cursorDate;
    String? cursorId;
    PrayerType? cursorPrayerType;

    while (true) {
      final page = await _localStore.getPage(
        userId: userId,
        limit: 500,
        prayerType: prayerType,
        status: status,
        afterOriginalDate: cursorDate,
        afterId: cursorId,
        afterPrayerType: cursorPrayerType,
      );
      records.addAll(page.records);
      if (!page.hasMore) return records;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
      cursorPrayerType = page.nextPrayerType;
    }
  }

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? toExclusive,
    DateTime? afterOriginalDate,
    String? afterId,
    PrayerType? afterPrayerType,
    DateTime? beforeOriginalDate,
    String? beforeId,
    PrayerType? beforePrayerType,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    _validateActive(userId);
    final page = await _localStore.getPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      additionId: additionId,
      from: from,
      to: to,
      toExclusive: toExclusive,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
      afterPrayerType: afterPrayerType,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
      beforePrayerType: beforePrayerType,
      afterCompletedAt: afterCompletedAt,
      beforeCompletedAt: beforeCompletedAt,
      descending: descending,
    );
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    _validateActive(userId);
    return _localStore.getOldestPending(
      userId: userId,
      prayerType: prayerType,
    );
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    _validateActive(userId);
    return _localStore.getRecordsByIds(
      userId: userId,
      ids: recordIds.toList(growable: false),
    );
  }

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    _validateActive(userId);
    final ids = recordIds.toSet();
    if (ids.isEmpty) return const <QazaRecord>[];

    final records = await _localStore.getRecordsByIds(
      userId: userId,
      ids: ids.toList(growable: false),
    );
    return records
        .where((record) => record.status == QazaStatus.pending)
        .toList(growable: false);
  }

  @override
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) {
    _validateActive(userId);
    return _localStore.getCompletedActivityRows(
      userId: userId,
      from: from,
      toExclusive: toExclusive,
      prayerTypes: prayerTypes,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) {
    _validateActive(userId);
    return _localStore.getProgressSummary(userId: userId);
  }

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) {
    _validateActive(userId);
    return _localStore.countCompletedBetween(
      userId: userId,
      from: from,
      to: to,
      prayerTypes: prayerTypes,
    );
  }

  @override
  Future<void> addRecord(QazaRecord record) => addRecords([record]);

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userId = _requireActive();
    final fresh = <QazaRecord>[];

    for (final record in records) {
      if (record.userId != userId || record.id.isEmpty) {
        throw StateError(
            'Cannot add a Qaza record for the active local ledger.');
      }

      final duplicate = await _localStore.hasRecordCombination(
        userId: userId,
        prayerType: record.prayerType,
        originalDate: record.originalDate,
      );
      if (duplicate) continue;
      fresh.add(record);
    }

    if (fresh.isNotEmpty) {
      await _localStore.appendRecords(userId, fresh);
    }
  }

  @override
  Future<int> addRecordsBulk(List<QazaRecord> records) async {
    if (records.isEmpty) return 0;
    final userId = _requireActive();
    for (final record in records) {
      if (record.userId != userId || record.id.isEmpty) {
        throw StateError(
            'Cannot add a Qaza record for the active local ledger.');
      }
    }

    final existingIds = (await _localStore.getRecordsByIds(
      userId: userId,
      ids: records.map((record) => record.id).toList(growable: false),
    ))
        .map((record) => record.id)
        .toSet();

    await _localStore.appendRecords(userId, records);
    return records.where((record) => !existingIds.contains(record.id)).length;
  }

  @override
  Future<bool> updateRecord({required QazaRecord record}) async {
    final userId = _requireActive();
    if (record.userId != userId || record.id.isEmpty) {
      throw StateError('Cannot update a Qaza record outside the local ledger.');
    }

    final duplicate = await _localStore.hasRecordCombination(
      userId: userId,
      prayerType: record.prayerType,
      originalDate: record.originalDate,
      excludingRecordId: record.id,
    );
    if (duplicate) {
      throw StateError(
        'A Qaza record already exists for this prayer and date.',
      );
    }

    return _localStore.updateRecord(record);
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    _validateActive(userId);
    await _localStore.deleteRecord(
      userId: userId,
      recordId: recordId,
    );
  }
  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
    String? completionId,
  }) async {
    _validateActive(userId);
    if (recordId.isEmpty) return QazaCompletionResult.notFound;

    final changed = await _localStore.completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
      completionIds: completionId == null
          ? null
          : <String, String>{recordId: completionId},
    );

    if (changed.isNotEmpty) {
      return QazaCompletionResult.completed;
    }

    final current = await _localStore.getRecordsByIds(
      userId: userId,
      ids: [recordId],
    );
    if (current.any(
      (record) =>
          record.status == QazaStatus.completed &&
          record.id == recordId &&
          record.userId == userId,
    )) {
      return QazaCompletionResult.alreadyCompleted;
    }

    return QazaCompletionResult.notFound;
  }

  @override
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) async {
    _validateActive(userId);
    if (recordIds.isEmpty) return const <QazaRecord>[];
    return _localStore.completeRecords(
      userId: userId,
      recordIds: recordIds.toSet().toList(growable: false),
      completedAt: completedAt,
      completionIds: completionIds,
    );
  }

  @override
  Future<List<String>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    _validateActive(userId);
    if (expectedCompletionIds.isEmpty) return const <String>[];
    final changed = await _localStore.undoCompletions(
      userId: userId,
      expectedCompletionIds: expectedCompletionIds,
      undoneAt: undoneAt,
    );
    return changed.map((record) => record.id).toList(growable: false);
  }

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) async {
    _validateActive(userId);
    return _localStore.markCompletedAsPendingBatch(
      userId: userId,
      expectedCompletionIds: expectedCompletionIds,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<QazaProfilePlanMutationResult> applyProfilePlanChanges({
    required String userId,
    required List<QazaRecord> additions,
    required List<String> removalIds,
    required Set<String> newPlanKeys,
    required String expectedPreviousPlanFingerprint,
  }) async {
    _validateActive(userId);
    return _localStore.applyProfilePlanChanges(
      userId: userId,
      additions: additions,
      removalIds: removalIds,
      newPlanKeys: newPlanKeys,
      expectedPreviousPlanFingerprint: expectedPreviousPlanFingerprint,
    );
  }

  @override
  Future<void> rollbackProfilePlanChanges(
    QazaProfilePlanMutationResult mutation,
  ) async {
    _validateActive(mutation.userId);
    return _localStore.rollbackProfilePlanChanges(mutation);
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    _validateActive(userId);
    await _localStore.retireUserData(userId: userId);
  }

  void dispose() {}

  String _requireActive() {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('No local Qaza ledger is active.');
    }
    return userId;
  }

  void _validateActive(String userId) {
    if (userId.isEmpty || userId != _activeUserId) {
      _diagnostics.recordFailure(
        DiagnosticArea.uncaught,
        'inactive_local_ledger_access',
        StateError('Qaza operation targeted a non-active local ledger.'),
      );
      throw StateError('Qaza operation targeted a non-active local ledger.');
    }
  }
}
