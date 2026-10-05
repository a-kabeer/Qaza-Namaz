import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/utils/qaza_completion_id.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../entities/qaza_completion_result.dart';
import '../repositories/qaza_repository.dart';
import '../repositories/qaza_bulk_delete_repository.dart';
import '../repositories/qaza_bulk_write_repository.dart';
import '../repositories/qaza_undo_repository.dart';
import 'current_day_qaza_eligibility_service.dart';
import 'qaza_availability_service.dart';
import 'profile_rules.dart';
export '../entities/qaza_progress.dart';
export '../repositories/qaza_repository.dart' show QazaPage;
export 'qaza_availability_service.dart'
    show QazaAvailabilityAnalysis, QazaEligibility, QazaPrayerKey;

class QazaRecordMutationConflictException implements Exception {
  const QazaRecordMutationConflictException();
}

class QazaWitrNotIncludedException implements Exception {
  const QazaWitrNotIncludedException();

  @override
  String toString() => 'Witr is not included in the current profile.';
}

class QazaDuplicateRecordException implements Exception {
  const QazaDuplicateRecordException();

  @override
  String toString() => 'A Qaza record already exists for this prayer and date.';
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
    int? processed,
    this.cancelled = false,
  }) : processed = processed ?? total;

  final int total;
  final int added;
  final int skipped;
  final int processed;
  final bool cancelled;
}

class QazaService {
  QazaService(
    this.repository, {
    QazaAvailabilityService? availability,
    this.witrInclusionResolver,
    DiagnosticsService? diagnostics,
  }) : availability = availability ?? const QazaAvailabilityService();

  final QazaRepository repository;
  final QazaAvailabilityService availability;
  final bool Function()? witrInclusionResolver;

  bool get _witrAllowed => witrInclusionResolver?.call() ?? true;

  List<PrayerType> get _enabledPrayerTypes =>
      ProfileRules.prayerTypesForWitr(_witrAllowed);

  QazaProgressSummary _scopeProgress(QazaProgressSummary summary) {
    final allowed = _enabledPrayerTypes.toSet();
    var pending = 0;
    var completed = 0;
    for (final prayer in allowed) {
      final progress = summary.byPrayer[prayer]?.progress;
      pending += progress?.pending ?? 0;
      completed += progress?.completed ?? 0;
    }
    return QazaProgressSummary(
      overall: QazaProgress(pending: pending, completed: completed),
      byPrayer: {
        for (final prayer in allowed)
          prayer: summary.byPrayer[prayer] ??
              PrayerProgress(
                prayerType: prayer,
                progress: const QazaProgress(pending: 0, completed: 0),
              ),
      },
    );
  }

  Future<List<QazaRecord>> getRecords(
          {required String userId,
          PrayerType? prayerType,
          QazaStatus? status}) =>
      repository.getRecords(
          userId: userId, prayerType: prayerType, status: status);
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
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
  }) =>
      repository.getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        prayerTypes: _enabledPrayerTypes,
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

  Future<QazaRecord?> oldestPending({
    required String userId,
    required PrayerType prayerType,
  }) {
    if (prayerType == PrayerType.witr && !_witrAllowed) {
      return Future.value(null);
    }
    return repository.getOldestPending(
      userId: userId,
      prayerType: prayerType,
    );
  }

  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) =>
      repository.getRecordsByIds(
        userId: userId,
        recordIds: recordIds,
      );

  /// Returns the next pending Qaza using the repository's normal ordering.
  Future<QazaRecord?> oldestPendingOverall({
    required String userId,
  }) async {
    final page = await repository.getPage(
      userId: userId,
      limit: 1,
      prayerTypes: _enabledPrayerTypes,
      status: QazaStatus.pending,
    );
    return page.records.isEmpty ? null : page.records.first;
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
        prayerTypes: _enabledPrayerTypes,
      );

  /// The most recent pending record for [prayerType], or null when there is
  /// none.
  ///
  /// Uses the generic ledger page in descending order, bounded to a single row.
  Future<QazaRecord?> latestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await repository.getPage(
      userId: userId,
      limit: 1,
      prayerType: prayerType,
      prayerTypes: _enabledPrayerTypes,
      status: QazaStatus.pending,
      descending: true,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) async {
    final summary = await repository.getProgressSummary(userId: userId);
    return _scopeProgress(summary);
  }

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
      DateTime? afterDate;
      String? afterId;
      PrayerType? afterPrayerType;
      while (true) {
        final page = await repository.getPage(
          userId: userId,
          limit: 500,
          prayerType: prayer,
          status: null,
          from: sortedDates.first,
          to: sortedDates.last,
          afterOriginalDate: afterDate,
          afterId: afterId,
          afterPrayerType: afterPrayerType,
        );
        result.addAll(page.records);
        if (!page.hasMore) break;
        afterDate = page.nextOriginalDate;
        afterId = page.nextId;
        afterPrayerType = page.nextPrayerType;
      }
    }
    return result;
  }

  Future<QazaAvailabilityAnalysis> analyzeAvailability(
      {required String userId,
      required Iterable<DateTime> dates,
      required Iterable<PrayerType> prayerTypes,
      Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
      String? editingAdditionId,
      CurrentDayQazaPrayerTimeContext? prayerTimeContext}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final existing = await _getExistingForAvailability(
        userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    return availability.analyze(
        userId: userId,
        dates: normalizedDates,
        prayerTypes: selectedPrayers,
        existingRecords: existing,
        prayedKeys: prayedKeys,
        editingAdditionId: editingAdditionId,
        prayerTimeContext: prayerTimeContext);
  }

  /// Returns the prayers still eligible on each requested date. Reads remain bounded to the requested dates.
  Future<Map<DateTime, Set<PrayerType>>> getAvailablePrayersByDate(
      {required String userId,
      required Iterable<DateTime> dates,
      Iterable<PrayerType> prayerTypes = PrayerType.values,
      Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
      String? editingAdditionId,
      CurrentDayQazaPrayerTimeContext? prayerTimeContext}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const {};
    final existing = await _getExistingForAvailability(
        userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    final retained = availability.currentAdditionRetainedKeys(
      existingRecords: existing,
      editingAdditionId: editingAdditionId,
    );
    final result = <DateTime, Set<PrayerType>>{};
    for (final date in normalizedDates) {
      final available = <PrayerType>{};
      for (final prayer in selectedPrayers) {
        final key =
            QazaPrayerKey(userId: userId, date: date, prayerType: prayer);
        if (retained.contains(key) ||
            availability.eligibility(
                  userId: userId,
                  date: date,
                  prayerType: prayer,
                  existingRecords: existing,
                  prayedKeys: prayedKeys,
                  prayerTimeContext: prayerTimeContext,
                ) ==
                QazaEligibility.available) {
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

    final currentRecords = await repository.getRecordsByIds(
      userId: userId,
      recordIds: [record.id],
    );
    if (currentRecords.isEmpty) {
      throw const QazaRecordMutationConflictException();
    }
    final current = currentRecords.first;
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

    final identityChanged =
        current.prayerType != record.prayerType ||
        QazaDate.key(current.originalDate) != QazaDate.key(normalizedDate);
    var recordToUpdate = current.copyWith(
      prayerType: record.prayerType,
      originalDate: normalizedDate,
      clearProfilePlanProvenance: identityChanged,
      updatedAt: DateTime.now(),
    );

    // An explicit edit to a completed row invalidates the old completion
    // marker, so a stale Undo action can never move a newer state backwards.
    if (current.status == QazaStatus.completed &&
        recordToUpdate.status == QazaStatus.completed &&
        current.completionId != null &&
        recordToUpdate.completionId == current.completionId) {
      recordToUpdate = recordToUpdate.copyWith(
        completionId: newQazaCompletionId(),
      );
    }

    final updated = await repository.updateRecord(record: recordToUpdate);
    if (!updated) throw const QazaRecordMutationConflictException();
  }

  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) =>
      repository.deleteRecord(
        userId: userId,
        recordId: recordId,
      );

  Future<int> deleteRecords({
    required String userId,
    required List<String> recordIds,
  }) async {
    if (recordIds.isEmpty) return 0;
    final ids = recordIds.toSet().where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return 0;

    if (repository is QazaBulkDeleteRepository) {
      return (repository as QazaBulkDeleteRepository).deleteRecords(
        userId: userId,
        recordIds: ids,
      );
    }

    var deleted = 0;
    for (final id in ids) {
      await repository.deleteRecord(userId: userId, recordId: id);
      deleted++;
    }
    return deleted;
  }

  Future<void> addRecords(List<QazaRecord> records) =>
      repository.addRecords(records);
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final receipt = await completeRecordWithReceipt(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
    return receipt.result;
  }

  Future<QazaCompletionReceipt> completeRecordWithReceipt({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final batch = await completeRecordsWithReceipt(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
    return QazaCompletionReceipt(
      result: batch.result,
      completionId:
          batch.entries.isEmpty ? null : batch.entries.single.completionId,
    );
  }

  /// The single interactive completion pipeline used by Home, Qaza swipe and
  /// Qaza batch completion.
  Future<QazaCompletionBatchReceipt> completeRecordsWithReceipt({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    final ids = recordIds.toSet().where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      return const QazaCompletionBatchReceipt(
        result: QazaCompletionResult.notFound,
        entries: [],
      );
    }

    final pending = await repository.getPendingRecordsByIds(
      userId: userId,
      recordIds: ids,
    );

    if (pending.isEmpty) {
      final current = await repository.getRecordsByIds(
        userId: userId,
        recordIds: ids,
      );
      return QazaCompletionBatchReceipt(
        result: current.any((record) => record.status == QazaStatus.completed)
            ? QazaCompletionResult.alreadyCompleted
            : QazaCompletionResult.notFound,
        entries: const [],
      );
    }

    final pendingIds =
        pending.map((record) => record.id).toList(growable: false);

    final completionIds = <String, String>{
      for (final id in pendingIds) id: newQazaCompletionId(),
    };
    final changed = await repository.completeRecords(
      userId: userId,
      recordIds: pendingIds,
      completedAt: completedAt,
      completionIds: completionIds,
    );

    final entries = <QazaCompletionEntry>[
      for (final record in changed)
        if (record.completedAt != null && record.completionId != null)
          QazaCompletionEntry(
            recordId: record.id,
            completionId: record.completionId!,
            prayerType: record.prayerType,
            originalDate: record.originalDate,
            completedAt: record.completedAt!,
          ),
    ];

    return QazaCompletionBatchReceipt(
      result: entries.isEmpty
          ? QazaCompletionResult.notFound
          : QazaCompletionResult.completed,
      entries: List.unmodifiable(entries),
    );
  }

  /// Legacy count-returning wrapper retained for older callers/tests.
  Future<int> completeSelected({
    required String userId,
    required List<String> recordIds,
    DateTime? completedAt,
  }) async {
    final receipt = await completeRecordsWithReceipt(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt ?? DateTime.now(),
    );
    return receipt.count;
  }

  /// Permanently corrects completed records after the temporary Undo
  /// window has expired. The persistence layer guards each selected row by
  /// its completion marker so a stale selection cannot overwrite newer state.
  Future<List<QazaRecord>> markCompletedRecordsAsPending({
    required String userId,
    required Map<String, String> expectedCompletionIds,
  }) {
    if (expectedCompletionIds.isEmpty) {
      return Future.value(const <QazaRecord>[]);
    }
    return repository.markCompletedAsPendingBatch(
      userId: userId,
      expectedCompletionIds: Map.unmodifiable(expectedCompletionIds),
      updatedAt: DateTime.now(),
    );
  }

  /// Permanently corrects one completed record after the temporary Undo
  /// window has expired. It re-reads the current completion marker before the
  /// guarded transition, so an old selection cannot move a newer completion.
  Future<bool> markCompletedAsPending({
    required String userId,
    required String recordId,
  }) async {
    final current = await repository.getRecordsByIds(
      userId: userId,
      recordIds: [recordId],
    );
    if (current.isEmpty ||
        current.first.status != QazaStatus.completed ||
        current.first.completionId == null) {
      return false;
    }

    final changed = await markCompletedRecordsAsPending(
      userId: userId,
      expectedCompletionIds: {
        recordId: current.first.completionId!,
      },
    );
    return changed.isNotEmpty;
  }

  /// Reverts only the completions captured by an active undo window.
  ///
  /// The persistence layer re-checks the exact completion marker so an old
  /// undo can never overwrite a later completion or conflict resolution.
  Future<List<String>> undoCompletions({
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
    DateTime? earliestDate,
    DateTime? today,
    bool? witrAllowed,
    CurrentDayQazaPrayerTimeContext? prayerTimeContext,
    String? profilePlanRevisionId,
    String? profilePlanFingerprint,
    bool Function()? isCancellationRequested,
  }) async {
    if (batchSize < 1) throw ArgumentError.value(batchSize, 'batchSize');
    onProgress?.call(const QazaImportProgress.preparing());

    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final witrResolver = witrInclusionResolver;
    final resolvedWitrAllowed =
        witrAllowed ?? (witrResolver == null ? true : witrResolver());
    if (selectedPrayers.contains(PrayerType.witr) && !resolvedWitrAllowed) {
      throw const QazaWitrNotIncludedException();
    }

    final normalizedEarliestDate =
        earliestDate == null ? null : QazaDate.normalize(earliestDate);
    final normalizedToday =
        today == null ? null : QazaDate.normalize(today);

    bool dateAllowed(DateTime date) {
      final normalized = QazaDate.normalize(date);
      if (normalizedToday != null && normalized.isAfter(normalizedToday)) {
        return false;
      }
      if (normalizedEarliestDate != null &&
          normalized.isBefore(normalizedEarliestDate)) {
        return false;
      }
      return true;
    }

    bool prayerAllowed(PrayerType prayer) =>
        prayer != PrayerType.witr || resolvedWitrAllowed;

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
    final analysis = availability.analyze(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
      existingRecords: existing,
      prayedKeys: prayedKeys,
      prayerTimeContext: prayerTimeContext,
    );
    final candidates = analysis.newCandidates
        .where((candidate) =>
            dateAllowed(candidate.date) && prayerAllowed(candidate.prayerType))
        .toList(growable: false);
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

    final now = DateTime.now();
    var processed = 0;
    var added = 0;
    for (var start = 0; start < total; start += batchSize) {
      if (isCancellationRequested?.call() ?? false) {
        return QazaImportResult(
          total: total,
          added: added,
          skipped: processed - added,
          processed: processed,
          cancelled: true,
        );
      }
      final end = start + batchSize < total ? start + batchSize : total;
      final batch = [
        for (final candidate in candidates.sublist(start, end))
          QazaRecord(
            id: candidate.value,
            userId: userId,
            prayerType: candidate.prayerType,
            originalDate: candidate.date,
            status: QazaStatus.pending,
            profilePlanRevisionId: profilePlanRevisionId,
            profilePlanFingerprint: profilePlanFingerprint,
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
      processed: total,
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
    PrayerType? afterPrayerType;
    while (remaining.isNotEmpty) {
      final page = await repository.getPage(
        userId: userId,
        limit: 500,
        status: QazaStatus.pending,
        afterOriginalDate: afterDate,
        afterId: afterId,
        afterPrayerType: afterPrayerType,
      );
      if (page.records.isEmpty) break;
      for (final record in page.records) {
        if (remaining.remove(record.id)) result.add(record);
      }
      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
      afterPrayerType = page.nextPrayerType;
    }
    return result;
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

  static QazaProgress progressOf(Iterable<QazaRecord> records) {
    var completed = 0;
    var total = 0;
    for (final record in records) {
      total++;
      if (record.status == QazaStatus.completed) completed++;
    }
    return QazaProgress(
        pending: total - completed < 0 ? 0 : total - completed,
        completed: completed);
  }
}
