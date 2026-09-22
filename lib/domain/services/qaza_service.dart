import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
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

typedef QazaPrayerTimeBlockedResolver = Future<Set<QazaPrayerKey>> Function({
  required String userId,
  required Iterable<DateTime> dates,
  required Iterable<PrayerType> prayerTypes,
});

class QazaDuplicateRecordException implements Exception {
  const QazaDuplicateRecordException();

  @override
  String toString() =>
      'A Qaza record already exists for this prayer and date.';
}

class QazaService {
  QazaService(
    this.repository, {
    QazaAvailabilityService? availability,
    SahibAlTartibService? tartib,
    QazaPrayerTimeBlockedResolver? prayerTimeBlockedResolver,
  })  : availability = availability ?? const QazaAvailabilityService(),
        tartib = tartib ?? SahibAlTartibService(repository),
        prayerTimeBlockedResolver = prayerTimeBlockedResolver;
  final QazaRepository repository;
  final QazaAvailabilityService availability;
  final SahibAlTartibService tartib;
  final QazaPrayerTimeBlockedResolver? prayerTimeBlockedResolver;

  Future<Set<QazaPrayerKey>> _getTimeBlockedKeys({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
  }) async {
    final resolver = prayerTimeBlockedResolver;
    if (resolver == null) return const <QazaPrayerKey>{};
    return resolver(userId: userId, dates: dates, prayerTypes: prayerTypes);
  }

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

  /// Returns the next Qaza allowed by the active Sahib al-Tartib rule.
  ///
  /// When fewer than six Fard prayers are pending, the next prayer is selected
  /// by date and the actual prayer sequence. Otherwise the existing bounded
  /// repository ordering is preserved.
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
    final state = await tartib.evaluate(userId: userId);
    if (!state.requiresOrder || state.nextPending == null) return;
    if (state.nextPending!.id != recordId) {
      throw QazaTartibViolationException(
        requiredPrayer: state.nextPending!.prayerType,
        pendingFarzCount: state.pendingFarzCount,
      );
    }
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
    final timeBlockedKeys = await _getTimeBlockedKeys(
      userId: userId,
      dates: normalizedDates,
      prayerTypes: selectedPrayers,
    );
    return availability.analyze(
        userId: userId,
        dates: normalizedDates,
        prayerTypes: selectedPrayers,
        existingRecords: existing,
        prayedKeys: prayedKeys,
        timeBlockedKeys: timeBlockedKeys);
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

    await repository.updateRecord(
      record: record.copyWith(
        originalDate: normalizedDate,
        updatedAt: DateTime.now(),
      ),
    );
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
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    await _ensureCompletionAllowed(
      userId: userId,
      recordId: recordId,
    );
    await repository.completeRecord(
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
    if (state.requiresOrder) {
      if (recordIds.length != 1 || state.nextPending == null) {
        throw QazaTartibViolationException(
          requiredPrayer: state.nextPrayer!,
          pendingFarzCount: state.pendingFarzCount,
        );
      }
      if (recordIds.single != state.nextPending!.id) {
        throw QazaTartibViolationException(
          requiredPrayer: state.nextPrayer!,
          pendingFarzCount: state.pendingFarzCount,
        );
      }
    }
    await repository.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }

  /// Reverts only the completions captured by an active undo window.
  ///
  /// The persistence layer re-checks the exact completion timestamp so an old
  /// undo can never overwrite a later edit or conflict resolution.
  Future<int> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  }) {
    if (repository is! QazaUndoRepository) {
      throw StateError('Qaza undo is not supported by this repository.');
    }
    return (repository as QazaUndoRepository).undoCompletions(
      userId: userId,
      expectedCompletedAt: expectedCompletedAt,
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

  /// Records every missing Qaza across [dates], returning how many were added.
  ///
  /// The duplicate analysis is unchanged and still runs once, over the whole
  /// request, before anything is written. Only the write is chunked: a twenty
  /// year estimate is tens of thousands of rows, and one write of that size
  /// leaves the caller with nothing to show for several seconds. [onProgress]
  /// is called after each batch with the running count and the total.
  Future<int> recordQazaForDates({
      required String userId,
      required Iterable<DateTime> dates,
      required Iterable<PrayerType> prayerTypes,
      Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
      int batchSize = 500,
      void Function(int processed, int total)? onProgress,
      String? operationId,
      DateTime? operationCreatedAt}) async {
    if (batchSize < 1) throw ArgumentError.value(batchSize, 'batchSize');
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) {
      onProgress?.call(0, 0);
      return 0;
    }
    final existing = await _getExistingForAvailability(
        userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
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
        timeBlockedKeys: timeBlockedKeys);
    final candidates = analysis.newCandidates.toList(growable: false);
    final total = candidates.length;
    // Reported even when there is nothing to do, so a caller showing progress
    // starts from a real total rather than a guess.
    onProgress?.call(0, total);
    if (total == 0) return 0;

    final now = operationCreatedAt ?? DateTime.now();
    var processed = 0;
    for (var start = 0; start < total; start += batchSize) {
      final end = start + batchSize < total ? start + batchSize : total;
      await repository.addRecords([
        for (final candidate in candidates.sublist(start, end))
          QazaRecord(
              id: operationId == null
                  ? candidate.value
                  : 'op_${operationId}_${candidate.value}',
              userId: userId,
              prayerType: candidate.prayerType,
              originalDate: candidate.date,
              status: QazaStatus.pending,
              createdAt: now,
              updatedAt: now)
      ]);
      processed = end;
      onProgress?.call(processed, total);
    }
    return total;
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
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) {
    if (repository is! QazaRecoveryRepository) {
      throw StateError('Qaza recovery is not supported by this repository.');
    }
    return (repository as QazaRecoveryRepository).getRecentlyDeletedPage(
      userId: userId,
      limit: limit,
      beforeOriginalDate: beforeOriginalDate,
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
