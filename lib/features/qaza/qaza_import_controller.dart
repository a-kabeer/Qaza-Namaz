import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_operation.dart';
import '../../domain/services/qaza_service.dart';

enum QazaImportTaskPhase { idle, preparing, importing, completed, failed }

@immutable
class QazaImportTaskState {
  const QazaImportTaskState({
    this.phase = QazaImportTaskPhase.idle,
    this.userId,
    this.processed = 0,
    this.total = 0,
    this.added = 0,
    this.skipped = 0,
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
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration? elapsed;
  final Object? error;

  bool get isActive =>
      phase == QazaImportTaskPhase.preparing ||
      phase == QazaImportTaskPhase.importing;

  double? get progress => total <= 0
      ? null
      : (processed / total).clamp(0.0, 1.0).toDouble();

  QazaImportTaskState copyWith({
    QazaImportTaskPhase? phase,
    String? userId,
    int? processed,
    int? total,
    int? added,
    int? skipped,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? elapsed,
    Object? error,
    bool clearError = false,
  }) => QazaImportTaskState(
        phase: phase ?? this.phase,
        userId: userId ?? this.userId,
        processed: processed ?? this.processed,
        total: total ?? this.total,
        added: added ?? this.added,
        skipped: skipped ?? this.skipped,
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
    required this.operationType,
    required this.inputSnapshot,
  });

  final String userId;
  final List<DateTime> dates;
  final Set<PrayerType> prayers;
  final QazaOperationType operationType;
  final Map<String, dynamic> inputSnapshot;
}

final qazaImportProvider =
    NotifierProvider<QazaImportController, QazaImportTaskState>(
  QazaImportController.new,
);

class QazaImportController extends Notifier<QazaImportTaskState> {
  _QazaImportRequest? _lastRequest;

  @override
  QazaImportTaskState build() => const QazaImportTaskState();

  bool start({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayers,
    required QazaOperationType operationType,
    required Map<String, dynamic> inputSnapshot,
  }) {
    if (state.isActive) return false;
    final dateList = dates.toList(growable: false);
    final prayerSet = prayers.toSet();
    if (userId.isEmpty || dateList.isEmpty || prayerSet.isEmpty) return false;

    final request = _QazaImportRequest(
      userId: userId,
      dates: dateList,
      prayers: prayerSet,
      operationType: operationType,
      inputSnapshot: Map.unmodifiable(inputSnapshot),
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

  bool retry() {
    final request = _lastRequest;
    if (request == null || state.isActive) return false;
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
    QazaOperation? operation;
    try {
      operation = await ref.read(qazaOperationServiceProvider).begin(
        userId: request.userId,
        type: request.operationType,
        inputSnapshot: request.inputSnapshot,
      );
      final result = await ref.read(qazaServiceProvider).importQazaForDates(
        userId: request.userId,
        dates: request.dates,
        prayerTypes: request.prayers,
        operationId: operation.operationId,
        operationCreatedAt: operation.createdAt,
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
      stopwatch.stop();
      await ref.read(qazaOperationServiceProvider).finish(
        operation,
        status: QazaOperationStatus.completed,
        affectedRecordCount: result.added,
      );
      ref.invalidate(progressSummaryProvider);
      state = state.copyWith(
        phase: QazaImportTaskPhase.completed,
        processed: result.total,
        total: result.total,
        added: result.added,
        skipped: result.skipped,
        completedAt: DateTime.now(),
        elapsed: stopwatch.elapsed,
        clearError: true,
      );
    } catch (error, stack) {
      stopwatch.stop();
      if (operation != null) {
        try {
          await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: state.added > 0
                ? QazaOperationStatus.partial
                : QazaOperationStatus.failed,
            affectedRecordCount: state.added,
            note: error.toString(),
          );
        } catch (finishError, finishStack) {
          ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'qaza_import_operation_finish_failed',
            finishError,
            stack: finishStack,
          );
        }
      }
      ref.invalidate(progressSummaryProvider);
      ref.read(diagnosticsProvider).recordFailure(
        DiagnosticArea.importData,
        'qaza_import_failed',
        error,
        stack: stack,
      );
      state = state.copyWith(
        phase: QazaImportTaskPhase.failed,
        completedAt: DateTime.now(),
        elapsed: stopwatch.elapsed,
        error: error,
      );
    }
  }
}
