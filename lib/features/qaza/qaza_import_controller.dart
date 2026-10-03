import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../domain/services/current_day_qaza_eligibility_service.dart';
import '../../domain/services/qaza_service.dart';

enum QazaImportTaskPhase {
  idle,
  preparing,
  importing,
  applyingProfile,
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
      phase == QazaImportTaskPhase.importing ||
      phase == QazaImportTaskPhase.applyingProfile;

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
    this.prayerTimeContext,
    this.profilePlanRevisionId,
    this.profilePlanFingerprint,
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
  final CurrentDayQazaPrayerTimeContext? prayerTimeContext;
  final String? profilePlanRevisionId;
  final String? profilePlanFingerprint;
}

final qazaImportProvider =
    NotifierProvider<QazaImportController, QazaImportTaskState>(
  QazaImportController.new,
);

class QazaImportController extends Notifier<QazaImportTaskState> {
  _QazaImportRequest? _lastRequest;
  Future<void> Function(void Function(int processed, int total) onProgress)?
      _lastProfileApply;
  int _lastProfileApplyTotal = 0;
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
    CurrentDayQazaPrayerTimeContext? prayerTimeContext,
    String? profilePlanRevisionId,
    String? profilePlanFingerprint,
  }) {
    if (state.isActive) return false;
    final dateList = dates.toList(growable: false);
    final prayerSet = prayers.toSet();
    if (userId.isEmpty || dateList.isEmpty || prayerSet.isEmpty) return false;
    if (additionId != null && expectedRevision == null) return false;

    _cancelRequested = false;

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
      prayerTimeContext: prayerTimeContext,
      profilePlanRevisionId: profilePlanRevisionId,
      profilePlanFingerprint: profilePlanFingerprint,
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

  bool startProfilePlanApply({
    required int total,
    required Future<void> Function(
      void Function(int processed, int total) onProgress,
    ) operation,
  }) {
    if (state.isActive || total < 0) return false;
    _lastProfileApply = operation;
    _lastProfileApplyTotal = total;
    state = QazaImportTaskState(
      phase: QazaImportTaskPhase.applyingProfile,
      total: total,
      startedAt: DateTime.now(),
    );
    unawaited(_runProfileApply(operation, total));
    return true;
  }

  Future<void> _runProfileApply(
    Future<void> Function(void Function(int processed, int total) onProgress)
        operation,
    int total,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final onProgress = (int processed, int progressTotal) {
        if (state.phase != QazaImportTaskPhase.applyingProfile) return;
        state = state.copyWith(
          processed: progressTotal <= 0 ? 0 : processed.clamp(0, progressTotal),
          total: progressTotal,
        );
      };
      await operation(onProgress);
      stopwatch.stop();
      if (state.phase == QazaImportTaskPhase.applyingProfile) {
        state = state.copyWith(
          phase: QazaImportTaskPhase.completed,
          processed: total,
          total: total,
          completedAt: DateTime.now(),
          elapsed: stopwatch.elapsed,
          clearError: true,
        );
      }
    } catch (error, stack) {
      stopwatch.stop();
      state = state.copyWith(
        phase: QazaImportTaskPhase.failed,
        completedAt: DateTime.now(),
        elapsed: stopwatch.elapsed,
        error: error,
      );
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'profile_qaza_plan_apply_failed',
            error,
            stack: stack,
          );
    }
  }

  bool cancel() {
    if (!state.isActive || state.cancelRequested) return false;
    state = state.copyWith(cancelRequested: true);
    _cancelRequested = true;
    return true;
  }

  bool retry() {
    if (state.isActive) return false;
    final profileApply = _lastProfileApply;
    if (profileApply != null) {
      state = QazaImportTaskState(
        phase: QazaImportTaskPhase.applyingProfile,
        total: _lastProfileApplyTotal,
        startedAt: DateTime.now(),
      );
      unawaited(_runProfileApply(profileApply, _lastProfileApplyTotal));
      return true;
    }
    final request = _lastRequest;
    if (request == null) return false;
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
              prayerTimeContext: request.prayerTimeContext,
              profilePlanRevisionId: request.profilePlanRevisionId,
              profilePlanFingerprint: request.profilePlanFingerprint,
              isCancellationRequested: () => _cancelRequested,
              onProgress: (progress) {
                if (!state.isActive || state.userId != request.userId) return;
                state = state.copyWith(
                  phase: progress.phase == QazaImportPhase.preparing
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
                  prayerTimeContext: request.prayerTimeContext,
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
