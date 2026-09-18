import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/guest_migration_service.dart';
import '../qaza/qaza_tracker_controller.dart';
import 'guest_session.dart';

final guestMigrationServiceProvider = Provider<GuestMigrationService>(
  (ref) => GuestMigrationService(ref.watch(qazaRepositoryProvider)),
);

/// Signs a guest in and carries their records across.
///
/// The order matters: the guest's records are read while the guest ledger is
/// still the active one, the account is signed in, and only then are the
/// records written into the account. Nothing is deleted on either side, so a
/// failure anywhere leaves the guest's data exactly where it was.
class GuestUpgradeController extends AutoDisposeNotifier<GuestUpgradeState> {
  @override
  GuestUpgradeState build() => const GuestUpgradeState();

  /// Signs in with Google, migrating guest records when there are any.
  ///
  /// Returns false when sign-in itself failed; the reader stays a guest.
  Future<bool> signInAndMigrate() async {
    if (state.running) return false;
    state = const GuestUpgradeState(running: true);
    final wasGuest = ref.read(isGuestProvider);

    try {
      final account = await ref.read(authRepositoryProvider).signInWithGoogle();

      var result = GuestMigrationResult.none;
      if (wasGuest) {
        result = await ref.read(guestMigrationServiceProvider).migrate(
              guestUserId: guestUserId,
              accountUserId: account.id,
            );
      }

      // Guest mode ends only once the records are safely in the account.
      await ref.read(guestSessionProvider.notifier).end();
      _refreshDerivedState();
      state = GuestUpgradeState(migration: result);
      return true;
    } catch (error) {
      state = GuestUpgradeState(error: error.toString());
      return false;
    }
  }

  /// Everything computed from the ledger now describes a different ledger.
  void _refreshDerivedState() {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(oldestPendingProvider);
    ref.invalidate(latestPendingProvider);
    ref.invalidate(qazaTrackerControllerProvider);
  }
}

class GuestUpgradeState {
  const GuestUpgradeState({
    this.running = false,
    this.migration = GuestMigrationResult.none,
    this.error,
  });

  final bool running;
  final GuestMigrationResult migration;
  final String? error;
}

final guestUpgradeControllerProvider =
    AutoDisposeNotifierProvider<GuestUpgradeController, GuestUpgradeState>(
  GuestUpgradeController.new,
);
