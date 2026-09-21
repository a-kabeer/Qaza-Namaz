import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/services/guest_migration_service.dart';
import '../qaza/qaza_tracker_controller.dart';
import 'guest_session.dart';

final guestMigrationServiceProvider = Provider<GuestMigrationService>(
  (ref) => GuestMigrationService(
    localStore: ref.watch(qazaLocalStoreProvider),
    remoteRepository: ref.watch(remoteQazaRepositoryProvider),
  ),
);

/// How long startup waits for Firebase's first auth emission.
///
/// The stream normally emits within milliseconds, from locally persisted
/// state, so this is not a latency budget — it is a stop for the case where
/// the emission never comes at all. A release build signed with a key the
/// Firebase project does not know, or one whose App Check attestation the
/// device cannot complete, can leave the Auth SDK without an initial event,
/// and `AuthGate` shows the splash screen for exactly as long as this
/// controller says it is restoring.
final startupAuthTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

/// Coordinates the guest -> Google account transition without ever auto-merging.
///
/// Firebase authentication and application-ledger switching are deliberately
/// separate phases. While [pendingAccount] is set, the guest-upgrade barrier
/// keeps the normal app ledger on the guest namespace.
class GuestUpgradeController extends AutoDisposeNotifier<GuestUpgradeState> {
  static const _pendingDecisionKey = 'qaza_guest_upgrade_decision';
  bool _userActionStarted = false;
  bool _disposed = false;

  @override
  GuestUpgradeState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(_restorePendingDecision);
    return const GuestUpgradeState(restoring: true);
  }

  Future<void> _restorePendingDecision() async {
    try {
      if (_userActionStarted) return;
      final prefs = await SharedPreferences.getInstance();
      final marker = prefs.getString(_pendingDecisionKey);
      // Wait for Firebase's initial auth emission before deciding whether a
      // persisted upgrade marker is stale. This prevents a cold-start auth
      // restoration from racing the pending-decision restoration.
      // Bounded on purpose. Waiting forever here is indistinguishable, from
      // the outside, from the app being frozen on its splash screen.
      final currentUser = await ref
          .read(authStateProvider.future)
          .timeout(ref.read(startupAuthTimeoutProvider), onTimeout: () => null);
      // Read the persisted guest flag directly so restoration cannot race the
      // async GuestSessionNotifier restore during cold start.
      final guestPersisted =
          prefs.getBool(GuestSessionNotifier.storageKey) ?? false;

      if (guestPersisted) {
        await ref.read(guestSessionProvider.notifier).ensureRestored();
      }

      if (_userActionStarted) return;

      if (marker == null || !guestPersisted || currentUser == null) {
        if (marker != null) {
          await prefs.remove(_pendingDecisionKey);
        }
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        state = const GuestUpgradeState();
        return;
      }

      final decoded = jsonDecode(marker);
      if (decoded is! Map<String, dynamic> ||
          decoded['accountId'] != currentUser.id) {
        await prefs.remove(_pendingDecisionKey);
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        state = const GuestUpgradeState();
        return;
      }

      await ref.read(guestUpgradePendingProvider.notifier).setPending(true);
      state = GuestUpgradeState(pendingAccount: currentUser);
    } catch (error) {
      if (_disposed) return;
      state = GuestUpgradeState(
        error: 'Could not restore the pending sign-in decision: $error',
      );
    } finally {
      // Whatever happened above — an early return because the user got there
      // first, a throw, or a timeout — restoration is over. Leaving this flag
      // set strands the app on the splash screen with no way out, so it is
      // cleared here rather than on each individual path.
      if (!_disposed && state.restoring) {
        state = GuestUpgradeState(
          running: state.running,
          pendingAccount: state.pendingAccount,
          migration: state.migration,
          error: state.error,
        );
      }
    }
  }

  /// Starts Google authentication. Guest data is never migrated automatically.
  ///
  /// For a guest, the ledger barrier is set before Firebase authentication so
  /// an authStateChanges event cannot switch normal app reads to the account
  /// before the explicit data decision.
  Future<bool> signInAndMigrate() async {
    if (state.running || state.pendingAccount != null) return false;
    _userActionStarted = true;

    // Resolve persisted guest mode before starting Firebase auth. Otherwise a
    // cold-start tap can authenticate directly into the account namespace and
    // leave the guest ledger stranded on the device.
    final wasGuest =
        await ref.read(guestSessionProvider.notifier).ensureRestored();
    state = const GuestUpgradeState(running: true);

    if (wasGuest) {
      await ref.read(guestUpgradePendingProvider.notifier).setPending(true);
    }

    try {
      final account = await ref.read(authRepositoryProvider).signInWithGoogle();

      if (!wasGuest) {
        state = const GuestUpgradeState();
        return true;
      }

      final hasGuestData = await ref
          .read(guestMigrationServiceProvider)
          .hasGuestData(guestUserId: guestUserId);

      if (!hasGuestData) {
        // End guest mode before lowering the barrier so activeUserIdProvider
        // changes directly from the reserved guest ledger to the account.
        await ref.read(guestSessionProvider.notifier).end();
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
        _refreshDerivedState();
        state = const GuestUpgradeState(
          migration: GuestMigrationResult.none,
        );
        return true;
      }

      await _persistPendingDecision(account.id);
      state = GuestUpgradeState(pendingAccount: account);
      return true;
    } on AuthenticationCancelledException {
      if (wasGuest) {
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
      }
      // A user cancellation is not an authentication/configuration failure.
      // Keep the current session exactly where it was before the attempt.
      state = const GuestUpgradeState();
      return false;
    } catch (error) {
      // A guest must never be left partially switched into an authenticated
      // account after a failed sign-in/preflight operation.
      if (wasGuest) {
        try {
          if (ref.read(authRepositoryProvider).currentUser != null) {
            await ref.read(authRepositoryProvider).signOut();
          }
        } catch (_) {
          // Keep the original authentication/preflight error for diagnostics.
        }
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
      }

      state = GuestUpgradeState(error: error.toString());
      return false;
    }
  }

  /// Merge guest records into the authenticated account, then retire guest data.
  Future<bool> mergeData() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    state = GuestUpgradeState(running: true, pendingAccount: account);
    try {
      final result = await ref.read(guestMigrationServiceProvider).migrate(
            guestUserId: guestUserId,
            accountUserId: account.id,
          );

      // Guest rows are retired only after the migration has completed and its
      // account-local state/outbox are durable and retry-safe.
      await ref
          .read(guestMigrationServiceProvider)
          .retireGuestData(guestUserId: guestUserId);

      await ref.read(guestSessionProvider.notifier).end();
      await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
      await _clearPendingDecision();
      _refreshDerivedState();

      state = GuestUpgradeState(migration: result);
      return true;
    } catch (error) {
      // Keep Firebase account + guest barrier in place. The user can retry;
      // guest data has not been retired.
      state = GuestUpgradeState(
        pendingAccount: account,
        error: error.toString(),
      );
      return false;
    }
  }

  /// Keep only the authenticated account ledger after an explicit confirmation.
  Future<bool> useAccountData() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    state = GuestUpgradeState(running: true, pendingAccount: account);
    try {
      await ref
          .read(guestMigrationServiceProvider)
          .retireGuestData(guestUserId: guestUserId);

      await ref.read(guestSessionProvider.notifier).end();
      await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
      await _clearPendingDecision();
      _refreshDerivedState();

      state = const GuestUpgradeState();
      return true;
    } catch (error) {
      state = GuestUpgradeState(
        pendingAccount: account,
        error: error.toString(),
      );
      return false;
    }
  }

  /// Cancel the account transition and remain a guest with guest data intact.
  Future<bool> cancelAndKeepGuest() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    state = GuestUpgradeState(running: true, pendingAccount: account);
    Object? signOutError;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      signOutError = error;
    }

    // FirebaseAuth may already be signed out even when Google local sign-out
    // reports a platform error. In that case the application is safely back in
    // guest mode and the guest ledger remains untouched.
    if (ref.read(authRepositoryProvider).currentUser == null) {
      await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
      await _clearPendingDecision();
      // Firebase is definitely signed out; keep the guest workspace as the
      // final state even if the Google SDK reported a secondary sign-out issue.
      state = const GuestUpgradeState();
      return true;
    }

    state = GuestUpgradeState(
      pendingAccount: account,
      error: signOutError?.toString() ??
          'Could not cancel the Google account transition.',
    );
    return false;
  }

  Future<void> _persistPendingDecision(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingDecisionKey,
      jsonEncode(<String, dynamic>{'accountId': accountId}),
    );
    await ref.read(guestUpgradePendingProvider.notifier).setPending(true);
  }

  Future<void> _clearPendingDecision() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingDecisionKey);
    } catch (_) {
      // The runtime barrier is cleared separately; a stale marker is harmless
      // because restoration validates the Firebase UID and guest session.
    }
  }

  /// Everything computed from the ledger now describes a different namespace.
  void _refreshDerivedState() {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(oldestPendingProvider);
    ref.invalidate(latestPendingProvider);
    ref.invalidate(qazaTrackerControllerProvider);
  }
}

class GuestUpgradeState {
  const GuestUpgradeState({
    this.restoring = false,
    this.running = false,
    this.pendingAccount,
    this.migration = GuestMigrationResult.none,
    this.error,
  });

  final bool restoring;
  final bool running;
  final AppUser? pendingAccount;
  final GuestMigrationResult migration;
  final String? error;

  bool get awaitingDecision => pendingAccount != null;
}

final guestUpgradeControllerProvider =
    AutoDisposeNotifierProvider<GuestUpgradeController, GuestUpgradeState>(
  GuestUpgradeController.new,
);
