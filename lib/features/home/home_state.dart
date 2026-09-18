/// High-level Home ledger states used to choose the user's primary journey.
enum HomeLedgerState { setupRequired, hasPendingQaza, allQazaCompleted }

enum HomePrimaryAction { calculateQaza, addQaza, completeQaza, addNewQaza }

class HomeStateResolver {
  const HomeStateResolver._();

  static HomeLedgerState ledgerState(
      {required int pending, required int completed}) {
    if (pending < 0 || completed < 0) {
      throw ArgumentError('Home progress counts cannot be negative.');
    }
    if (pending > 0) return HomeLedgerState.hasPendingQaza;
    if (completed > 0) return HomeLedgerState.allQazaCompleted;
    return HomeLedgerState.setupRequired;
  }

  static HomePrimaryAction primaryAction(HomeLedgerState state) =>
      switch (state) {
        HomeLedgerState.setupRequired => HomePrimaryAction.calculateQaza,
        HomeLedgerState.hasPendingQaza => HomePrimaryAction.completeQaza,
        HomeLedgerState.allQazaCompleted => HomePrimaryAction.addNewQaza,
      };

  static HomePrimaryAction secondaryAction(HomeLedgerState state) =>
      switch (state) {
        HomeLedgerState.setupRequired => HomePrimaryAction.addQaza,
        HomeLedgerState.hasPendingQaza => HomePrimaryAction.addQaza,
        HomeLedgerState.allQazaCompleted => HomePrimaryAction.calculateQaza,
      };
}
