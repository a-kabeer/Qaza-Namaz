import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_startup_state.dart';
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

  /// Where the transition currently in progress was started from.
  ///
  /// Held on the controller rather than threaded through every call: a
  /// transition has one origin from the tap that starts it until it resolves,
  /// and every state emitted in between has to carry it or `AuthGate` loses
  /// track of whose screen it is allowed to replace.
  GuestUpgradeOrigin _origin = GuestUpgradeOrigin.startup;

  /// Emits a state stamped with the current [_origin].
  void _emit({
    bool running = false,
    AppUser? pendingAccount,
    GuestMigrationResult migration = GuestMigrationResult.none,
    GuestDataSummary summary = GuestDataSummary.empty,
    bool newAccount = false,
    String? error,
  }) {
    state = GuestUpgradeState(
      running: running,
      pendingAccount: pendingAccount,
      migration: migration,
      summary: summary,
      newAccount: newAccount,
      error: error,
      origin: _origin,
    );
  }

  @override
  GuestUpgradeState build() {
    _disposed = false;
    _origin = GuestUpgradeOrigin.startup;
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
        _emit();
        return;
      }

      final decoded = jsonDecode(marker);
      if (decoded is! Map<String, dynamic> ||
          decoded['accountId'] != currentUser.id) {
        await prefs.remove(_pendingDecisionKey);
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        _emit();
        return;
      }

      await ref.read(guestUpgradePendingProvider.notifier).setPending(true);
      _emit(pendingAccount: currentUser);
    } catch (error) {
      if (_disposed) return;
      _emit(error: 'Could not restore the pending sign-in decision: $error');
    } finally {
      // Whatever happened above — an early return because the user got there
      // first, a throw, or a timeout — restoration is over. Leaving this flag
      // set strands the app on the splash screen with no way out, so it is
      // cleared here rather than on each individual path.
      if (!_disposed && state.restoring) {
        _emit(
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
  Future<bool> signInAndMigrate({
    GuestUpgradeOrigin origin = GuestUpgradeOrigin.startup,
  }) async {
    if (state.running || state.pendingAccount != null) return false;
    _userActionStarted = true;
    _origin = origin;

    final wasGuest =
        await ref.read(guestSessionProvider.notifier).ensureRestored();
    final migration = ref.read(guestMigrationServiceProvider);
    final hasLocalQaza =
        await migration.hasGuestData(guestUserId: guestUserId);

    _emit(running: true);
    if (wasGuest || hasLocalQaza) {
      await ref.read(guestUpgradePendingProvider.notifier).setPending(true);
    }

    try {
      final repository = ref.read(authRepositoryProvider);
      final result = repository is DetailedAuthRepository
          ? await repository.signInWithGoogleDetails()
          : GoogleSignInResult(
              user: await repository.signInWithGoogle(),
              isNewUser: false,
            );
      final account = result.user;

      if (result.isNewUser) {
        await AuthStartupState.markNewGoogleUser(account.id);

        // A brand-new Google account has no existing cloud Qaza ledger, so
        // locally-created records can be associated with it without asking
        // the user to reconcile two account datasets. This is still explicit
        // account creation, not an automatic merge with an existing account.
        if (hasLocalQaza) {
          final migrated = await migration.migrate(
            guestUserId: guestUserId,
            accountUserId: account.id,
          );
          await migration.retireGuestData(guestUserId: guestUserId);
          await AuthStartupState.clear();
          await ref.read(guestSessionProvider.notifier).end();
          await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
          _refreshDerivedState();
          _emit(migration: migrated, newAccount: true);
          return true;
        }

        await ref.read(guestSessionProvider.notifier).end();
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
        _refreshDerivedState();
        _emit(newAccount: true);
        return true;
      }

      if (!hasLocalQaza) {
        if (wasGuest) {
          await ref.read(guestSessionProvider.notifier).end();
        }
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
        _refreshDerivedState();
        _emit();
        return true;
      }

      final summary = await migration.summarize(
        guestUserId: guestUserId,
        accountUserId: account.id,
      );
      await _persistPendingDecision(account.id);
      _emit(pendingAccount: account, summary: summary);
      return true;
    } on AuthenticationCancelledException catch (error) {
      if (wasGuest || hasLocalQaza) {
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
      }

      _emit(error: error.userInitiated ? null : error.diagnostic);
      return false;
    } catch (error) {
      try {
        if (ref.read(authRepositoryProvider).currentUser != null &&
            (wasGuest || hasLocalQaza)) {
          await ref.read(authRepositoryProvider).signOut();
        }
      } catch (_) {
        // Preserve the original authentication/migration error.
      }

      if (wasGuest || hasLocalQaza) {
        await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
        await _clearPendingDecision();
      }

      _emit(error: error.toString());
      return false;
    }
  }

  /// Merge guest records into the authenticated account, then retire guest data.
  Future<bool> mergeData() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    _emit(
      running: true,
      pendingAccount: account,
      summary: state.summary,
    );
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

      _emit(migration: result);
      return true;
    } catch (error) {
      // Keep Firebase account + guest barrier in place. The user can retry;
      // guest data has not been retired.
      _emit(pendingAccount: account, error: error.toString());
      return false;
    }
  }

  /// Keep only the authenticated account ledger after an explicit confirmation.
  Future<bool> useAccountData() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    _emit(running: true, pendingAccount: account);
    try {
      await ref
          .read(guestMigrationServiceProvider)
          .retireGuestData(guestUserId: guestUserId);

      await ref.read(guestSessionProvider.notifier).end();
      await ref.read(guestUpgradePendingProvider.notifier).setPending(false);
      await _clearPendingDecision();
      _refreshDerivedState();

      _emit();
      return true;
    } catch (error) {
      _emit(pendingAccount: account, error: error.toString());
      return false;
    }
  }

  /// Cancel the account transition and remain a guest with guest data intact.
  Future<bool> cancelAndKeepGuest() async {
    final account = state.pendingAccount;
    if (account == null || state.running) return false;

    _emit(running: true, pendingAccount: account);
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
      _emit();
      return true;
    }

    _emit(
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

/// Where the guest -> account transition was started from.
///
/// [startup] is the pre-auth journey `AuthGate` owns: Welcome ->
/// Authentication -> decision -> Home. [inApp] is a sign-in the user began
/// from a screen they were already using, such as Settings. The distinction
/// exists because `AuthGate` replaces the whole app with the startup
/// Authentication navigator while a transition is unresolved; doing that to
/// someone who tapped "Back up / Sign in" in Settings throws them out of the
/// screen they were on, and a failure there should leave them exactly where
/// they were, free to retry.
enum GuestUpgradeOrigin { startup, inApp }

class GuestUpgradeState {
  const GuestUpgradeState({
    this.restoring = false,
    this.running = false,
    this.pendingAccount,
    this.migration = GuestMigrationResult.none,
    this.summary = GuestDataSummary.empty,
    this.newAccount = false,
    this.error,
    this.origin = GuestUpgradeOrigin.startup,
  });

  final bool restoring;
  final bool running;
  final AppUser? pendingAccount;
  final GuestMigrationResult migration;
  final GuestDataSummary summary;
  final bool newAccount;
  final String? error;
  final GuestUpgradeOrigin origin;

  bool get awaitingDecision => pendingAccount != null;
}

final guestUpgradeControllerProvider =
    AutoDisposeNotifierProvider<GuestUpgradeController, GuestUpgradeState>(
  GuestUpgradeController.new,
);
