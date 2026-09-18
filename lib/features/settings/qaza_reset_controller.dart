import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../qaza/qaza_tracker_controller.dart';

/// State of the "Reset Qaza Counter" action.
///
/// [recordCount] is the size of the ledger that was deleted, captured before
/// the delete so the confirmation message can report what actually went.
class QazaResetState {
  const QazaResetState({this.running = false, this.recordCount, this.error});

  final bool running;
  final int? recordCount;
  final String? error;

  QazaResetState copyWith({bool? running, int? recordCount, String? error}) =>
      QazaResetState(
          running: running ?? this.running,
          recordCount: recordCount ?? this.recordCount,
          error: error);
}

/// Owns the reset flow so no widget talks to the repository or the database.
///
/// The controller is the only place that knows a reset is "delete the ledger
/// and refresh everything derived from it"; the Settings row just calls it.
class QazaResetController extends AutoDisposeNotifier<QazaResetState> {
  @override
  QazaResetState build() => const QazaResetState();

  /// Deletes every Qaza record for the signed-in user.
  ///
  /// Returns true when the ledger was cleared. A signed-out user is a
  /// no-op rather than an error state the UI would have to explain.
  Future<bool> reset() async {
    if (state.running) return false;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return false;
    state = const QazaResetState(running: true);
    try {
      final service = ref.read(qazaServiceProvider);
      final summary = await service.getProgressSummary(userId: userId);
      await service.resetQazaCounter(userId: userId);
      // Everything derived from the ledger is now stale.
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(oldestPendingProvider);
      ref.invalidate(qazaTrackerControllerProvider);
      state = QazaResetState(recordCount: summary.overall.total);
      return true;
    } catch (error) {
      state = QazaResetState(error: error.toString());
      return false;
    }
  }
}

final qazaResetControllerProvider =
    AutoDisposeNotifierProvider<QazaResetController, QazaResetState>(
  QazaResetController.new,
);
