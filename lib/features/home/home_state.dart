/// High-level Home ledger states used to choose the user's primary journey.
///
/// This model is intentionally independent of the local storage implementation
/// so Home can consume either the current repository or the future Drift-backed
/// summary without changing the UX state machine.
enum HomeLedgerState {
  /// No Qaza records exist yet; guide the user to setup.
  setupRequired,

  /// At least one pending Qaza record exists; completion is the primary task.
  hasPendingQaza,

  /// Qaza records exist, but none are currently pending.
  allQazaCompleted,
}

/// Primary action presented by Home for the current ledger state.
enum HomePrimaryAction {
  calculateQaza,
  addQaza,
  completeQaza,
  addNewQaza,
}

/// Pure state resolver for Home.
///
/// Loading, error, and sync states remain orthogonal to this ledger state and
/// should be handled by the presentation/data layer rather than encoded here.
class HomeStateResolver {
  const HomeStateResolver._();

  static HomeLedgerState ledgerState({
    required int pending,
    required int completed,
  }) {
    if (pending < 0 || completed < 0) {
      throw ArgumentError('Home progress counts cannot be negative.');
    }
    if (pending > 0) return HomeLedgerState.hasPendingQaza;
    if (completed > 0) return HomeLedgerState.allQazaCompleted;
    return HomeLedgerState.setupRequired;
  }

  static HomePrimaryAction primaryAction(HomeLedgerState state) {
    return switch (state) {
      HomeLedgerState.setupRequired => HomePrimaryAction.calculateQaza,
      HomeLedgerState.hasPendingQaza => HomePrimaryAction.completeQaza,
      HomeLedgerState.allQazaCompleted => HomePrimaryAction.addNewQaza,
    };
  }

  /// Secondary setup action that complements the primary action for each state.
  static HomePrimaryAction secondaryAction(HomeLedgerState state) {
    return switch (state) {
      HomeLedgerState.setupRequired => HomePrimaryAction.addQaza,
      HomeLedgerState.hasPendingQaza => HomePrimaryAction.addQaza,
      HomeLedgerState.allQazaCompleted => HomePrimaryAction.calculateQaza,
    };
  }
}
