import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/utils/qaza_completion_id.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../entities/qaza_completion_result.dart';
import '../repositories/qaza_repository.dart';
import '../repositories/qaza_bulk_write_repository.dart';
import '../repositories/qaza_undo_repository.dart';
import '../repositories/qaza_recovery_repository.dart';
import 'qaza_availability_service.dart';
import 'sahib_al_tartib_service.dart';

export '../entities/qaza_progress.dart';
export '../repositories/qaza_repository.dart' show QazaHistoryPage, QazaPage;
export 'qaza_availability_service.dart'
    show QazaAvailabilityAnalysis, QazaEligibility, QazaPrayerKey;
export 'sahib_al_tartib_service.dart'
    show QazaTartibViolationException, SahibAlTartibState;

class QazaWitrNotIncludedException implements Exception {
  const QazaWitrNotIncludedException();

  @override
  String toString() => 'Witr is not included in the current profile.';
}

class QazaDuplicateRecordException implements Exception {
  const QazaDuplicateRecordException();

  @override
  String toString() =>
      'A Qaza record already exists for this prayer and date.';
}

enum QazaImportPhase { preparing, importing }

class QazaImportProgress {
  const QazaImportProgress({
    required this.phase,
    required this.processed,
    required this.total,
    required this.added,
    required this.skipped,
  });

  const QazaImportProgress.preparing()
      : phase = QazaImportPhase.preparing,
        processed = 0,
        total = 0,
        added = 0,
        skipped = 0;

  const QazaImportProgress.importing({
    required this.processed,
    required this.total,
    required this.added,
    required this.skipped,
  }) : phase = QazaImportPhase.importing;

  final QazaImportPhase phase;
  final int processed;
  final int total;
  final int added;
  final int skipped;
}

class QazaImportResult {
  const QazaImportResult({
    required this.total,
    required this.added,
    required this.skipped,
  });

  final int total;
  final int added;
  final int skipped;
}

class QazaService {
  QazaService(
    this.repository, {
    QazaAvailabilityService? availability,
    SahibAlTartibService? tartib,
    bool Function()? witrInclusionResolver,
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  })  : availability = availability ?? const QazaAvailabilityService(),
        tartib = tartib ?? SahibAlTartibService(repository),
        witrInclusionResolver = witrInclusionResolver,
        _diagnostics = diagnostics;
  final QazaRepository repository;
  final DiagnosticsService _diagnostics;
  final QazaAvailabilityService availability;
  final SahibAlTartibService tartib;
  final bool Function()? witrInclusionResolver;

  Future<List<QazaRecord>> getRecords(
          {required String userId,
          PrayerType? prayerType,
          QazaStatus? status}) =>
      repository.getRecords(
          userId: userId, prayerType: prayerType, status: status);
  Future<QazaPage> getPage(
          {required String userId,
          int limit = 50,
          PrayerType? prayerType,
          QazaStatus? status,
          DateTime? from,
          DateTime? to,
          DateTime? afterOriginalDate,
          String? afterId}) =>
      repository.getPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: status,
          from: from,
          to: to,
          afterOriginalDate: afterOriginalDate,
          afterId: afterId);
  Future<QazaRecord?> oldestPending(
          {required String userId, required PrayerType prayerType}) =>
      repository.getOldestPending(userId: userId, prayerType: prayerType);

  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) =>
      repository.getRecordsByIds(
        userId: userId,
        recordIds: recordIds,
      );

  /// Returns the next Qaza under the global Sahib al-Tartib rule.
  ///
  /// When fewer than six Fard Qaza remain, the tartib service chooses the
  /// oldest pending Fard using date, Fard prayer order, and id. At six or more
  /// pending Fard, tartib does not restrict completion and the repository's
  /// normal oldest-first ordering is preserved.
  Future<QazaRecord?> oldestPendingOverall({required String userId}) async {
    final tartibState = await tartib.evaluate(userId: userId);
    if (tartibState.requiresOrder) return tartibState.nextPending;

    final page = await repository.getPage(
      userId: userId,
      limit: 1,
      status: QazaStatus.pending,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<SahibAlTartibState> sahibAlTartibState({
    required String userId,
  }) =>
      tartib.evaluate(userId: userId);

  Future<void> _ensureCompletionAllowed({
    required String userId,
    required String recordId,
  }) async {
    final SahibAlTartibState state;
    final bool allowed;
    try {
      state = await tartib.evaluate(userId: userId);
      if (!state.requiresOrder || state.nextPending == null) return;
      allowed = await tartib.canCompleteRecordIds(
        userId: userId,
        recordIds: [recordId],
      );
    } catch (error, stack) {
      // The ordering rule could not be read. That is not a violation and not
      // a persistence failure; it is reported and rethrown so the caller can
      // say which of the two it was.
      _diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'tartib_check_failed',
        error,
        stack: stack,
      );
      rethrow;
    }
    if (allowed) {
      return;
    }
    throw QazaTartibViolationException(
      requiredPrayer: state.nextPending!.prayerType,
      pendingFarzCount: state.pendingFarzCount,
    );
  }

  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) =>
      repository.countCompletedBetween(
        userId: userId,
        from: from,
        to: to,
      );

  /// The most recent pending record for [prayerType], or null when there is
  /// none.
  ///
  /// Uses the history page, which the data source already returns newest
  /// first, bounded to a single row — no ledger is materialized to find it.
  Future<QazaRecord?> latestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await repository.getHistoryPage(
      userId: userId,
      limit: 1,
      prayerType: prayerType,
      status: QazaStatus.pending,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<QazaHistoryPage> getHistoryPage(
          {required String userId,
          int limit = 50,
          PrayerType? prayerType,
          QazaStatus? status = QazaStatus.completed,
          DateTime? from,
          DateTime? to,
          DateTime? beforeOriginalDate,
          String? beforeId}) =>
      repository.getHistoryPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: status,
          from: from,
          to: to,
          beforeOriginalDate: beforeOriginalDate,
          beforeId: beforeId);
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      repository.getProgressSummary(userId: userId);
  Future<List<QazaRecord>> getPendingForUser({required String userId}) =>
      getRecords(userId: userId, status: QazaStatus.pending);
  Future<List<QazaRecord>> getPendingForPrayer(
          {required String userId, required PrayerType prayerType}) =>
      getRecords(
          userId: userId, prayerType: prayerType, status: QazaStatus.pending);

  Future<List<QazaRecord>> _getExistingForAvailability(
      {required String userId,
      required Iterable<DateTime> dates,
      required Iterable<PrayerType> prayerTypes}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const [];
    final sortedDates = normalizedDates.toList()..sort();
    final result = <QazaRecord>[];
    for (final prayer in selectedPrayers) {
      DateTime? beforeDate;
      String? beforeId;
      while (true) {
        final page = await repository.getHistoryPage(
            userId: userId,
            limit: 500,
            prayerType: prayer,
            status: null,
            from: sortedDates.first,
            to: sortedDates.last,
            beforeOriginalDate: beforeDate,
            beforeId: beforeId);
        result.addAll(page.records);
        if (!page.hasMore) break;
        beforeDate = page.nextOriginalDate;
        beforeId = page.nextId;
      }
    }
    return result;
  }

  Future<QazaAvailabilityAnalysis> analyzeAvailability(
      {required String userId,
      required Iterable<DateTime> dates,
      required Iterable<PrayerType> prayerTypes,
      Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final existing = await _getExistingForAvailability(
        userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    return availability.analyze(
        userId: userId,
        dates: normalizedDates,
        prayerTypes: selectedPrayers,
        existingRecords: existing,
        prayedKeys: prayedKeys);
  }

  /// Returns the prayers still eligible on each requested date. Reads remain bounded to the requested dates.
  Future<Map<DateTime, Set<PrayerType>>> getAvailablePrayersByDate(
      {required String userId,
      required Iterable<DateTime> dates,
      Iterable<PrayerType> prayerTypes = PrayerType.values,
      Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const {};
    final existing = await _getExistingForAvailability(
        userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    final timeBlockedKeys = await _getTimeBlockedKeys(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
    );
    final recorded = availability.recordedKeys(existing);
    final result = <DateTime, Set<PrayerType>>{};
    for (final date in normalizedDates) {
      final available = <PrayerType>{};
      for (final prayer in selectedPrayers) {
        final key =
            QazaPrayerKey(userId: userId, date: date, prayerType: prayer);
        if (!prayedKeys.contains(key) &&
            !recorded.contains(key) &&
            !timeBlockedKeys.contains(key)) {
          available.add(prayer);
        }
      }
      result[date] = Set.unmodifiable(available);
    }
    return Map.unmodifiable(result);
  }

  /// Updates only the editable fields of a Qaza record.
  ///
  /// Record identity, status, completion timestamp and creation time remain
  /// unchanged. The prayer/date combination remains unique per user.
  Future<void> updateRecord({
    required String userId,
    required QazaRecord record,
  }) async {
    if (userId.isEmpty || record.userId != userId || record.id.isEmpty) {
      throw ArgumentError('Invalid Qaza record update.');
    }

    final normalizedDate = QazaDate.normalize(record.originalDate);
    final existing = await repository.getPage(
      userId: userId,
      limit: 2,
      prayerType: record.prayerType,
      status: null,
      from: normalizedDate,
      to: normalizedDate,
    );
    if (existing.records.any((candidate) => candidate.id != record.id)) {
      throw const QazaDuplicateRecordException();
    }

    var recordToUpdate = record.copyWith(
      originalDate: normalizedDate,
      updatedAt: DateTime.now(),
    );

    // An explicit local edit to an already-completed Qaza starts a new
    // completion version. This invalidates an older Undo action while leaving
    // server-only timestamp reconciliation marker-stable.
    final current = (await repository.getRecordsByIds(
      userId: userId,
      recordIds: [record.id],
    )).firstOrNull;
    if (current != null &&
        current.status == QazaStatus.completed &&
        recordToUpdate.status == QazaStatus.completed &&
        current.completionId != null &&
        recordToUpdate.completionId == current.completionId) {
      recordToUpdate = recordToUpdate.copyWith(
        completionId: newQazaCompletionId(),
      );
    }

    await repository.updateRecord(record: recordToUpdate);
  }

  Future<void> deleteRecord({
    required String userId,
    required String recordId,
    String? operationId,
    DateTime? deletedAt,
  }) async {
    if (userId.isEmpty || recordId.isEmpty) {
      throw ArgumentError('Invalid Qaza record deletion.');
    }
    final recovery = repository is QazaRecoveryRepository
        ? repository as QazaRecoveryRepository
        : null;
    if (recovery != null) {
      await recovery.softDeleteRecords(
        userId: userId,
        recordIds: [recordId],
        deletedAt: deletedAt ?? DateTime.now(),
        operationId: operationId ?? 'legacy_delete',
      );
      return;
    }
    await repository.deleteRecord(userId: userId, recordId: recordId);
  }

  Future<void> addRecords(List<QazaRecord> records) =>
      repository.addRecords(records);
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    await _ensureCompletionAllowed(
      userId: userId,
      recordId: recordId,
    );
    return repository.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
  }

  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty) return;
    final state = await tartib.evaluate(userId: userId);
    if (state.requiresOrder &&
        !(await tartib.canCompleteRecordIds(
          userId: userId,
          recordIds: recordIds,
        ))) {
      throw QazaTartibViolationException(
        requiredPrayer: state.nextPrayer!,
        pendingFarzCount: state.pendingFarzCount,
      );
    }
    await repository.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }

  /// Reverts only the completions captured by an active undo window.
  ///
  /// The persistence layer re-checks the exact completion marker so an old
  /// undo can never overwrite a later completion or conflict resolution.
  Future<int> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) {
    if (repository is! QazaUndoRepository) {
      throw StateError('Qaza undo is not supported by this repository.');
    }
    return (repository as QazaUndoRepository).undoCompletions(
      userId: userId,
      expectedCompletionIds: expectedCompletionIds,
      undoneAt: undoneAt,
    );
  }

  /// Resets the Qaza counter for [userId] by deleting the entire ledger.
  ///
  /// Both pending and completed records go, which is what makes this
  /// destructive: the counter returns to zero and the completion history that
  /// produced it is gone with it.
  Future<void> resetQazaCounter({required String userId}) =>
      repository.resetUserRecords(userId: userId);

  Future<void> recordQaza(
          {required String userId,
          required PrayerType prayerType,
          required DateTime originalDate}) =>
      recordQazaForDates(
          userId: userId, dates: [originalDate], prayerTypes: [prayerType]);

  /// Imports all currently eligible combinations with two observable phases:
  /// preparation and database writing.
  Future<QazaImportResult> importQazaForDates({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
    int batchSize = 500,
    void Function(QazaImportProgress progress)? onProgress,
    String? operationId,
    DateTime? operationCreatedAt,
  }) async {
    if (batchSize < 1) throw ArgumentError.value(batchSize, 'batchSize');
    onProgress?.call(const QazaImportProgress.preparing());

    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final witrResolver = witrInclusionResolver;
    if (selectedPrayers.contains(PrayerType.witr) &&
        witrResolver != null &&
        !witrResolver()) {
      throw const QazaWitrNotIncludedException();
    }

    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) {
      onProgress?.call(const QazaImportProgress.importing(
        processed: 0,
        total: 0,
        added: 0,
        skipped: 0,
      ));
      return const QazaImportResult(total: 0, added: 0, skipped: 0);
    }

    final existing = await _getExistingForAvailability(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
    );
    final timeBlockedKeys = await _getTimeBlockedKeys(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
    );
    final analysis = availability.analyze(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      existingRecords: existing,
      prayedKeys: prayedKeys,
    );
    final candidates = analysis.newCandidates.toList(growable: false);
    final total = candidates.length;
    onProgress?.call(QazaImportProgress.importing(
      processed: 0,
      total: total,
      added: 0,
      skipped: 0,
    ));
    if (total == 0) {
      return const QazaImportResult(total: 0, added: 0, skipped: 0);
    }

    final now = operationCreatedAt ?? DateTime.now();
    var processed = 0;
    var added = 0;
    for (var start = 0; start < total; start += batchSize) {
      final end = start + batchSize < total ? start + batchSize : total;
      final batch = [
        for (final candidate in candidates.sublist(start, end))
          QazaRecord(
            id: candidate.value,
            userId: userId,
            operationId: operationId,
            prayerType: candidate.prayerType,
            originalDate: candidate.date,
            status: QazaStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
      ];

      final written = repository is QazaBulkWriteRepository
          ? await (repository as QazaBulkWriteRepository).addRecordsBulk(batch)
          : await _addLegacyBatch(batch);
      processed = end;
      added += written;
      onProgress?.call(QazaImportProgress.importing(
        processed: processed,
        total: total,
        added: added,
        skipped: processed - added,
      ));
    }

    return QazaImportResult(
      total: total,
      added: added,
      skipped: total - added,
    );
  }

  Future<int> _addLegacyBatch(List<QazaRecord> batch) async {
    if (batch.isEmpty) return 0;
    await repository.addRecords(batch);
    return batch.length;
  }

  /// Backward-compatible entry point. New large-import UI uses
  /// [importQazaForDates] so it can distinguish preparation from writing.
  Future<int> recordQazaForDates({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
    int batchSize = 500,
    void Function(int processed, int total)? onProgress,
    String? operationId,
    DateTime? operationCreatedAt,
  }) async {
    final result = await importQazaForDates(
      userId: userId,
      dates: dates,
      prayerTypes: prayerTypes,
      prayedKeys: prayedKeys,
      batchSize: batchSize,
      onProgress: onProgress == null
          ? null
          : (progress) => onProgress(progress.processed, progress.total),
      operationId: operationId,
      operationCreatedAt: operationCreatedAt,
    );
    return result.added;
  }

  Future<bool> completeOldestPending(
      {required String userId,
      required PrayerType prayerType,
      DateTime? completedAt}) async {
    final record = await oldestPending(userId: userId, prayerType: prayerType);
    if (record == null) return false;
    await completeRecord(
        userId: userId,
        recordId: record.id,
        completedAt: completedAt ?? DateTime.now());
    return true;
  }

  Future<List<QazaRecord>> resolvePendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final remaining = recordIds.toSet();
    if (remaining.isEmpty) return const <QazaRecord>[];
    final result = <QazaRecord>[];
    DateTime? afterDate;
    String? afterId;
    while (remaining.isNotEmpty) {
      final page = await repository.getPage(
        userId: userId,
        limit: 500,
        status: QazaStatus.pending,
        afterOriginalDate: afterDate,
        afterId: afterId,
      );
      if (page.records.isEmpty) break;
      for (final record in page.records) {
        if (remaining.remove(record.id)) result.add(record);
      }
      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }
    return result;
  }

  Future<int> completeSelected(
      {required String userId,
      required List<String> recordIds,
      DateTime? completedAt}) async {
    final remaining = recordIds.toSet();
    if (remaining.isEmpty) return 0;
    final valid = <String>[];
    DateTime? afterDate;
    String? afterId;
    while (remaining.isNotEmpty) {
      final page = await repository.getPage(
          userId: userId,
          limit: 500,
          status: QazaStatus.pending,
          afterOriginalDate: afterDate,
          afterId: afterId);
      for (final record in page.records) {
        if (remaining.remove(record.id)) valid.add(record.id);
      }
      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }
    if (valid.isEmpty) return 0;
    await completeRecords(
        userId: userId,
        recordIds: valid,
        completedAt: completedAt ?? DateTime.now());
    return valid.length;
  }


  Future<QazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
    QazaStatus? status,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).getOperationPage(
      userId: userId,
      operationId: operationId,
      matchLastAction: matchLastAction,
      operationAt: operationAt,
      limit: limit,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
      status: status,
    );
  }

  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).getRecentlyDeletedPage(
      userId: userId,
      limit: limit,
      beforeDeletedAt: beforeDeletedAt,
      beforeId: beforeId,
    );
  }

  Future<int> deleteRecordsWithRecovery({
    required String userId,
    required List<String> recordIds,
    required DateTime deletedAt,
    required String operationId,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).softDeleteRecords(
      userId: userId,
      recordIds: recordIds,
      deletedAt: deletedAt,
      operationId: operationId,
    );
  }

  Future<int> restoreDeletedRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime restoredAt,
    required String operationId,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).restoreDeletedRecords(
      userId: userId,
      recordIds: recordIds,
      restoredAt: restoredAt,
      operationId: operationId,
    );
  }

  Future<int> undoAddedOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).undoAddedOperation(
      userId: userId,
      operationId: operationId,
      expectedCreatedAt: expectedCreatedAt,
    );
  }

  Future<int> removeAddition({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).removeAddition(
      userId: userId,
      operationId: operationId,
      expectedCreatedAt: expectedCreatedAt,
      deletedAt: deletedAt,
    );
  }

  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).getOperationSummary(
      userId: userId,
      operationId: operationId,
    );
  }

  Future<int> purgeDeletedBefore({
    required String userId,
    required DateTime cutoff,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).purgeDeletedBefore(
      userId: userId,
      cutoff: cutoff,
    );
  }

  Future<QazaProgress> overallProgress(String userId) async =>
      (await getProgressSummary(userId: userId)).overall;
  Future<PrayerProgress> prayerProgress(
          String userId, PrayerType prayerType) async =>
      (await getProgressSummary(userId: userId)).byPrayer[prayerType] ??
      PrayerProgress(
          prayerType: prayerType,
          progress: const QazaProgress(pending: 0, completed: 0));

  static List<QazaRecord> completedNewestFirst(Iterable<QazaRecord> records) {
    final completed = records
        .where((record) => record.status == QazaStatus.completed)
        .toList();
    completed.sort((a, b) => (b.completedAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return completed;
  }

  Future<List<QazaRecord>> history(String userId) async {
    final result = <QazaRecord>[];
    DateTime? date;
    String? id;
    while (true) {
      final page = await getHistoryPage(
          userId: userId,
          limit: 500,
          status: QazaStatus.completed,
          beforeOriginalDate: date,
          beforeId: id);
      result.addAll(page.records);
      if (!page.hasMore) return result;
      date = page.nextOriginalDate;
      id = page.nextId;
    }
  }

  static QazaProgress progressOf(Iterable<QazaRecord> records) {
    var completed = 0;
    var total = 0;
    for (final record in records) {
      if (record.status == QazaStatus.deleted) continue;
      total++;
      if (record.status == QazaStatus.completed) completed++;
    }
    return QazaProgress(
        pending: total - completed < 0 ? 0 : total - completed,
        completed: completed);
  }
}