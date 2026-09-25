import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/repositories/qaza_bulk_write_repository.dart';
import '../../domain/repositories/qaza_undo_repository.dart';
import '../../domain/repositories/qaza_recovery_repository.dart';
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
        QazaBulkWriteRepository,
        QazaUndoRepository,
        QazaRecoveryRepository {
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

    while (true) {
      final page = await _localStore.getPage(
        userId: userId,
        limit: 500,
        prayerType: prayerType,
        status: status,
        afterOriginalDate: cursorDate,
        afterId: cursorId,
      );
      records.addAll(page.records);
      if (!page.hasMore) return records;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
    }
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
    _validateActive(userId);
    final page = await _localStore.getPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
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
    _validateActive(userId);
    final page = await _localStore.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
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
  }) {
    _validateActive(userId);
    return _localStore.countCompletedBetween(
      userId: userId,
      from: from,
      to: to,
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
        throw StateError('Cannot add a Qaza record for the active local ledger.');
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
        throw StateError('Cannot add a Qaza record for the active local ledger.');
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
  Future<void> updateRecord({required QazaRecord record}) async {
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

    await _localStore.updateRecord(record);
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
  }) async {
    _validateActive(userId);
    if (recordId.isEmpty) return QazaCompletionResult.notFound;

    final changed = await _localStore.completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
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
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    _validateActive(userId);
    if (recordIds.isEmpty) return;
    await _localStore.completeRecords(
      userId: userId,
      recordIds: recordIds.toSet().toList(growable: false),
      completedAt: completedAt,
    );
  }

  @override
  Future<int> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    _validateActive(userId);
    if (expectedCompletionIds.isEmpty) return 0;
    final changed = await _localStore.undoCompletions(
      userId: userId,
      expectedCompletionIds: expectedCompletionIds,
      undoneAt: undoneAt,
    );
    return changed.length;
  }

  @override
  Future<int> softDeleteRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime deletedAt,
    required String operationId,
  }) async {
    _validateActive(userId);
    if (recordIds.isEmpty) return 0;

    final records = await _localStore.getRecordsByIds(
      userId: userId,
      ids: recordIds,
    );
    var changed = 0;

    for (final record in records) {
      if (record.isDeleted) continue;
      final deleted = record.copyWith(
        status: QazaStatus.deleted,
        updatedAt: deletedAt,
      );
      if (await _localStore.updateRecord(deleted)) {
        changed++;
      }
    }
    return changed;
  }

  @override
  Future<int> restoreDeletedRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime restoredAt,
    required String operationId,
  }) async {
    _validateActive(userId);
    if (recordIds.isEmpty) return 0;

    final records = await _localStore.getRecordsByIds(
      userId: userId,
      ids: recordIds,
    );
    var changed = 0;

    for (final record in records) {
      if (!record.isDeleted) continue;

      final duplicate = await _localStore.hasRecordCombination(
        userId: userId,
        prayerType: record.prayerType,
        originalDate: record.originalDate,
        excludingRecordId: record.id,
      );
      if (duplicate) continue;

      final restored = record.copyWith(
        status: record.completedAt == null
            ? QazaStatus.pending
            : QazaStatus.completed,
        updatedAt: restoredAt,
      );
      if (await _localStore.updateRecord(restored)) {
        changed++;
      }
    }
    return changed;
  }

  @override
  Future<int> undoAddedOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
  }) =>
      _removeUnchangedPendingFromOperation(
        userId: userId,
        operationId: operationId,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: DateTime.now(),
      );

  @override
  Future<int> removeAddition({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) =>
      _removeUnchangedPendingFromOperation(
        userId: userId,
        operationId: operationId,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: deletedAt,
      );

  Future<int> _removeUnchangedPendingFromOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) async {
    _validateActive(userId);
    DateTime? cursorDate;
    String? cursorId;
    var removed = 0;

    while (true) {
      final page = await _localStore.getOperationPage(
        userId: userId,
        operationId: operationId,
        matchLastAction: false,
        operationAt: expectedCreatedAt,
        status: QazaStatus.pending,
        limit: 200,
        beforeOriginalDate: cursorDate,
        beforeId: cursorId,
      );
      if (page.records.isEmpty) break;

      for (final record in page.records) {
        if (!record.createdAt.isAtSameMomentAs(expectedCreatedAt) ||
            !record.updatedAt.isAtSameMomentAs(expectedCreatedAt)) {
          continue;
        }
        removed += await softDeleteRecords(
          userId: userId,
          recordIds: [record.id],
          deletedAt: deletedAt,
          operationId: operationId,
        );
      }

      if (!page.hasMore) break;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
    }
    return removed;
  }

  @override
  Future<QazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    _validateActive(userId);
    final page = await _localStore.getOperationPage(
      userId: userId,
      operationId: operationId,
      matchLastAction: matchLastAction,
      operationAt: operationAt,
      status: status,
      limit: limit,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) {
    _validateActive(userId);
    return _localStore.getOperationSummary(
      userId: userId,
      operationId: operationId,
    );
  }

  @override
  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) async {
    _validateActive(userId);
    final page = await _localStore.getRecentlyDeletedPage(
      userId: userId,
      limit: limit,
      beforeDeletedAt: beforeDeletedAt,
      beforeId: beforeId,
    );
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<int> purgeDeletedBefore({
    required String userId,
    required DateTime cutoff,
  }) async {
    _validateActive(userId);
    DateTime? cursorDeletedAt;
    String? cursorId;
    var removed = 0;

    while (true) {
      final page = await _localStore.getRecentlyDeletedPage(
        userId: userId,
        limit: 200,
        beforeDeletedAt: cursorDeletedAt,
        beforeId: cursorId,
      );
      if (page.records.isEmpty) break;

      for (final record in page.records) {
        if (record.updatedAt.isBefore(cutoff) &&
            await _localStore.deleteRecord(
              userId: userId,
              recordId: record.id,
            )) {
          removed++;
        }
      }

      if (!page.hasMore) break;
      final last = page.records.last;
      cursorDeletedAt = last.updatedAt;
      cursorId = last.id;
    }
    return removed;
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
