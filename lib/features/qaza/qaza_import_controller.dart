import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_addition.dart';

enum QazaImportTaskPhase {
  idle,
  preparing,
  importing,
  completed,
  cancelled,
  failed,
}

@immutable
class QazaImportTaskState {
  const QazaImportTaskState({
    this.phase = QazaImportTaskPhase.idle,
    this.userId,
    this.processed = 0,
    this.total = 0,
    this.added = 0,
    this.skipped = 0,
    this.removed = 0,
    this.protected = 0,
    this.additionId,
    this.revision,
    this.cancelRequested = false,
    this.startedAt,
    this.completedAt,
    this.elapsed,
    this.error,
  });

  final QazaImportTaskPhase phase;
  final String? userId;
  final int processed;
  final int total;
  final int added;
  final int skipped;
  final int removed;
  final int protected;
  final String? additionId;
  final int? revision;
  final bool cancelRequested;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration? elapsed;
  final Object? error;

  bool get isActive =>
      phase == QazaImportTaskPhase.preparing ||
      phase == QazaImportTaskPhase.importing;

  double? get progress =>
      total <= 0 ? null : (processed / total).clamp(0.0, 1.0).toDouble();

  QazaImportTaskState copyWith({
    QazaImportTaskPhase? phase,
    String? userId,
    int? processed,
    int? total,
    int? added,
    int? skipped,
    int? removed,
    int? protected,
    String? additionId,
    int? revision,
    bool? cancelRequested,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? elapsed,
    Object? error,
    bool clearError = false,
  }) =>
      QazaImportTaskState(
        phase: phase ?? this.phase,
        userId: userId ?? this.userId,
        processed: processed ?? this.processed,
        total: total ?? this.total,
        added: added ?? this.added,
        skipped: skipped ?? this.skipped,
        removed: removed ?? this.removed,
        protected: protected ?? this.protected,
        additionId: additionId ?? this.additionId,
        revision: revision ?? this.revision,
        cancelRequested: cancelRequested ?? this.cancelRequested,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        elapsed: elapsed ?? this.elapsed,
        error: clearError ? null : error ?? this.error,
      );
}

class _QazaImportRequest {
  const _QazaImportRequest({
    required this.userId,
    required this.dates,
    required this.prayers,
    this.mode,
    this.additionId,
    this.expectedRevision,
    this.earliestDate,
    this.today,
    this.witrAllowed = true,
  });

  final String userId;
  final List<DateTime> dates;
  final Set<PrayerType> prayers;
  final QazaAdditionMode? mode;
  final String? additionId;
  final int? expectedRevision;
  final DateTime? earliestDate;
  final DateTime? today;
  final bool witrAllowed;
}

final qazaImportProvider =
    NotifierProvider<QazaImportController, QazaImportTaskState>(
  QazaImportController.new,
);

class QazaImportController extends Notifier<QazaImportTaskState> {
  _QazaImportRequest? _lastRequest;
  bool _cancelRequested = false;

  @override
  QazaImportTaskState build() => const QazaImportTaskState();

  bool start({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayers,
    QazaAdditionMode? mode,
    String? additionId,
    int? expectedRevision,
    DateTime? earliestDate,
    DateTime? today,
    bool witrAllowed = true,
  }) {
    if (state.isActive) return false;
    final dateList = dates.toList(growable: false);
    final prayerSet = prayers.toSet();
    if (userId.isEmpty || dateList.isEmpty || prayerSet.isEmpty) return false;
    if (additionId != null && expectedRevision == null) return false;

    final request = _QazaImportRequest(
      userId: userId,
      dates: dateList,
      prayers: prayerSet,
      mode: mode,
      additionId: additionId,
      expectedRevision: expectedRevision,
      earliestDate: earliestDate,
      today: today,
      witrAllowed: witrAllowed,
    );
    _lastRequest = request;
    state = QazaImportTaskState(
      phase: QazaImportTaskPhase.preparing,
      userId: userId,
      startedAt: DateTime.now(),
    );
    unawaited(_run(request));
    return true;
  }

  bool cancel() {
    if (!state.isActive || state.cancelRequested) return false;
    state = state.copyWith(cancelRequested: true);
    _cancelRequested = true;
    return true;
  }

  bool retry() {
    final request = _lastRequest;
    if (request == null || state.isActive) return false;
    _cancelRequested = false;
    state = QazaImportTaskState(
      phase: QazaImportTaskPhase.preparing,
      userId: request.userId,
      startedAt: DateTime.now(),
    );
    unawaited(_run(request));
    return true;
  }

  Future<void> _run(_QazaImportRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (request.mode == null) {
        final legacy = await ref.read(qazaServiceProvider).importQazaForDates(
              userId: request.userId,
              dates: request.dates,
              prayerTypes: request.prayers,
              earliestDate: request.earliestDate,
              today: request.today,
              witrAllowed: request.witrAllowed,
              isCancellationRequested: () => _cancelRequested,
              onProgress: (progress) {
                if (!state.isActive || state.userId != request.userId) return;
                state = state.copyWith(
                  phase: progress.phase == QazaImportProgressPhase.preparing
                      ? QazaImportTaskPhase.preparing
                      : QazaImportTaskPhase.importing,
                  processed: progress.processed,
                  total: progress.total,
                  added: progress.added,
                  skipped: progress.skipped,
                );
              },
            );
        if (legacy.cancelled) {
          state = state.copyWith(
            phase: QazaImportTaskPhase.cancelled,
            cancelRequested: false,
            completedAt: DateTime.now(),
            clearError: true,
          );
        } else {
          ref.invalidate(progressSummaryProvider);
          state = state.copyWith(
            phase: QazaImportTaskPhase.completed,
            cancelRequested: false,
            processed: legacy.processed,
            total: legacy.total,
            added: legacy.added,
            skipped: legacy.skipped,
            completedAt: DateTime.now(),
            clearError: true,
          );
        }
      } else {
        final result =
            await ref.read(qazaAdditionServiceProvider).createOrEdit(
                  userId: request.userId,
                  mode: request.mode!,
                  selectedDates: request.dates,
                  selectedPrayers: request.prayers,
                  additionId: request.additionId,
                  expectedRevision: request.expectedRevision,
                  earliestDate: request.earliestDate,
                  today: request.today,
                  witrAllowed: request.witrAllowed,
                  isCancellationRequested: () => _cancelRequested,
                  onProgress: (processed, total, added) {
                    if (!state.isActive || state.userId != request.userId) {
                      return;
                    }
                    state = state.copyWith(
                      phase: QazaImportTaskPhase.importing,
                      processed: processed,
                      total: total,
                      added: added,
                      skipped: processed - added,
                    );
                  },
                );

        if (result.cancelled) {
          state = state.copyWith(
            phase: QazaImportTaskPhase.cancelled,
            cancelRequested: false,
            completedAt: DateTime.now(),
            clearError: true,
          );
        } else {
          ref.invalidate(progressSummaryProvider);
          state = state.copyWith(
            phase: QazaImportTaskPhase.completed,
            cancelRequested: false,
            processed: result.addedCount + result.skippedCount,
            total: result.addedCount + result.skippedCount,
            added: result.addedCount,
            skipped: result.skippedCount,
            removed: result.removedCount,
            protected: result.protectedCount,
            additionId: result.additionId,
            revision: result.revision,
            completedAt: DateTime.now(),
            elapsed: stopwatch.elapsed,
            clearError: true,
          );
        }
      }
      stopwatch.stop();

      if (result.cancelled) {
        state = state.copyWith(
          phase: QazaImportTaskPhase.cancelled,
          cancelRequested: false,
          completedAt: DateTime.now(),
          elapsed: stopwatch.elapsed,
          clearError: true,
        );
        return;
      }

      ref.invalidate(progressSummaryProvider);
      state = state.copyWith(
        phase: QazaImportTaskPhase.completed,
        cancelRequested: false,
        processed: result.addedCount + result.skippedCount,
        total: result.addedCount + result.skippedCount,
        added: result.addedCount,
        skipped: result.skippedCount,
        removed: result.removedCount,
        protected: result.protectedCount,
        additionId: result.additionId,
        revision: result.revision,
        completedAt: DateTime.now(),
        elapsed: stopwatch.elapsed,
        clearError: true,
      );
    } catch (error, stack) {
      stopwatch.stop();
      ref.invalidate(progressSummaryProvider);
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'qaza_addition_failed',
            error,
            stack: stack,
          );
      state = state.copyWith(
        phase: QazaImportTaskPhase.failed,
        cancelRequested: false,
        completedAt: DateTime.now(),
        elapsed: stopwatch.elapsed,
        error: error,
      );
    }
  }
}
