import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/utils/qaza_completion_id.dart';
import 'package:qaza_namaz/core/utils/qaza_date.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/current_day_qaza_eligibility_service.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/repositories/qaza_addition_repository.dart';

class QazaAdditionService {
  const QazaAdditionService({
    required this.qazaService,
    required this.repository,
  });

  final QazaService qazaService;
  final QazaAdditionRepository repository;

  Future<QazaAdditionMutationResult> create({
    required String userId,
    required QazaAdditionMode mode,
    required List<DateTime> selectedDates,
    required Set<PrayerType> selectedPrayers,
    DateTime? earliestDate,
    DateTime? today,
    bool witrAllowed = true,
    CurrentDayQazaPrayerTimeContext? prayerTimeContext,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  }) async {
    final snapshot = _snapshot(
      mode: mode,
      selectedDates: selectedDates,
      selectedPrayers: selectedPrayers,
    );
    final candidates = await _eligibleNewCandidates(
      userId: userId,
      snapshot: snapshot,
      earliestDate: earliestDate,
      today: today,
      witrAllowed: witrAllowed,
      prayerTimeContext: prayerTimeContext,
    );

    if (isCancellationRequested?.call() ?? false) {
      return const QazaAdditionMutationResult(cancelled: true);
    }
    if (candidates.isEmpty) return const QazaAdditionMutationResult();

    final additionId = newQazaCompletionId();
    final now = DateTime.now();
    final records = candidates
        .map(
          (candidate) => QazaRecord(
            id: candidate.value,
            userId: userId,
            additionId: additionId,
            prayerType: candidate.prayerType,
            originalDate: QazaDate.normalize(candidate.date),
            status: QazaStatus.pending,
            recordVersion: 1,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList(growable: false);

    final addition = QazaAddition(
      id: additionId,
      userId: userId,
      mode: mode,
      currentInputSnapshot: snapshot,
      revision: 1,
      createdAt: now,
      updatedAt: now,
    );

    return repository.createAddition(
      addition: addition,
      records: records,
      isCancellationRequested: isCancellationRequested,
      onProgress: onProgress,
    );
  }

  Future<QazaAdditionMutationResult> edit({
    required String userId,
    required String additionId,
    required int expectedRevision,
    required QazaAdditionMode mode,
    required List<DateTime> selectedDates,
    required Set<PrayerType> selectedPrayers,
    DateTime? earliestDate,
    DateTime? today,
    bool witrAllowed = true,
    CurrentDayQazaPrayerTimeContext? prayerTimeContext,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  }) async {
    final current = await repository.getAddition(
      userId: userId,
      additionId: additionId,
    );
    if (current == null) {
      throw StateError('Qaza addition was not found.');
    }
    if (current.revision != expectedRevision) {
      throw StateError(
        'This Qaza addition was changed elsewhere. Reopen it and try again.',
      );
    }

    final snapshot = _snapshot(
      mode: mode,
      selectedDates: selectedDates,
      selectedPrayers: selectedPrayers,
    );
    final requestedKeys = <QazaRecordKey>{
      for (final date in snapshot.expandedDates)
        for (final prayer in snapshot.selectedPrayers)
          QazaRecordKey(date: date, prayerType: prayer),
    };

    final candidates = await _eligibleNewCandidates(
      userId: userId,
      snapshot: snapshot,
      earliestDate: earliestDate,
      today: today,
      witrAllowed: witrAllowed,
      prayerTimeContext: prayerTimeContext,
    );
    if (isCancellationRequested?.call() ?? false) {
      return const QazaAdditionMutationResult(cancelled: true);
    }

    final now = DateTime.now();
    final recordsToAdd = candidates
        .map(
          (candidate) => QazaRecord(
            id: candidate.value,
            userId: userId,
            additionId: additionId,
            prayerType: candidate.prayerType,
            originalDate: QazaDate.normalize(candidate.date),
            status: QazaStatus.pending,
            recordVersion: 1,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList(growable: false);

    return repository.editAddition(
      userId: userId,
      additionId: additionId,
      expectedRevision: expectedRevision,
      snapshot: snapshot,
      requestedKeys: requestedKeys,
      recordsToAdd: recordsToAdd,
      isCancellationRequested: isCancellationRequested,
      onProgress: onProgress,
    );
  }

  Future<QazaAdditionMutationResult> createOrEdit({
    required String userId,
    required QazaAdditionMode mode,
    required List<DateTime> selectedDates,
    required Set<PrayerType> selectedPrayers,
    String? additionId,
    int? expectedRevision,
    DateTime? earliestDate,
    DateTime? today,
    bool witrAllowed = true,
    CurrentDayQazaPrayerTimeContext? prayerTimeContext,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  }) {
    if (additionId == null) {
      return create(
        userId: userId,
        mode: mode,
        selectedDates: selectedDates,
        selectedPrayers: selectedPrayers,
        earliestDate: earliestDate,
        today: today,
        witrAllowed: witrAllowed,
        prayerTimeContext: prayerTimeContext,
        isCancellationRequested: isCancellationRequested,
        onProgress: onProgress,
      );
    }
    if (expectedRevision == null) {
      throw ArgumentError('expectedRevision is required when editing.');
    }
    return edit(
      userId: userId,
      additionId: additionId,
      expectedRevision: expectedRevision,
      mode: mode,
      selectedDates: selectedDates,
      selectedPrayers: selectedPrayers,
      earliestDate: earliestDate,
      today: today,
      witrAllowed: witrAllowed,
      prayerTimeContext: prayerTimeContext,
      isCancellationRequested: isCancellationRequested,
      onProgress: onProgress,
    );
  }

  QazaAdditionInputSnapshot _snapshot({
    required QazaAdditionMode mode,
    required List<DateTime> selectedDates,
    required Set<PrayerType> selectedPrayers,
  }) {
    final dates = selectedDates.map(QazaDate.normalize).toList(growable: false);
    final prayers = selectedPrayers.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: mode,
      selectedDates: List.unmodifiable(dates),
      selectedPrayers: List.unmodifiable(prayers),
    );
  }

  Future<List<QazaPrayerKey>> _eligibleNewCandidates({
    required String userId,
    required QazaAdditionInputSnapshot snapshot,
    required DateTime? earliestDate,
    required DateTime? today,
    required bool witrAllowed,
    required CurrentDayQazaPrayerTimeContext? prayerTimeContext,
  }) async {
    if (snapshot.expandedDates.isEmpty || snapshot.selectedPrayers.isEmpty) {
      return const <QazaPrayerKey>[];
    }

    final normalizedEarliest =
        earliestDate == null ? null : QazaDate.normalize(earliestDate);
    final normalizedToday = today == null ? null : QazaDate.normalize(today);

    final analysis = await qazaService.analyzeAvailability(
      userId: userId,
      dates: snapshot.expandedDates,
      prayerTypes: snapshot.selectedPrayers,
      prayerTimeContext: prayerTimeContext,
    );

    return analysis.newCandidates
        .where(
          (candidate) =>
              _dateAllowed(
                candidate.date,
                normalizedEarliest: normalizedEarliest,
                normalizedToday: normalizedToday,
              ) &&
              (candidate.prayerType != PrayerType.witr || witrAllowed),
        )
        .toList(growable: false);
  }

  bool _dateAllowed(
    DateTime date, {
    required DateTime? normalizedEarliest,
    required DateTime? normalizedToday,
  }) {
    final normalized = QazaDate.normalize(date);
    if (normalizedToday != null && normalized.isAfter(normalizedToday)) {
      return false;
    }
    if (normalizedEarliest != null &&
        normalized.isBefore(normalizedEarliest)) {
      return false;
    }
    return true;
  }
}
