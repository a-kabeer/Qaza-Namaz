import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The account id a guest's records belong to.
///
/// A fixed, reserved value: Firebase user ids are opaque and never this, so
/// guest data and any signed-in account's data can never share a namespace.
const String guestUserId = 'guest';

/// Whether the app is being used without signing in.
///
/// Persisted, so a guest who closes the app comes back to their ledger rather
/// than to the welcome screen. Signing in ends it; the guest's records are
/// migrated or explicitly retired after the user's decision.
class GuestSessionNotifier extends Notifier<bool> {
  static const String storageKey = 'qaza_guest_mode';
  bool _explicitStateSet = false;

  @override
  bool build() {
    Future.microtask(restore);
    return false;
  }

  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A startup restore can race an explicit start/end action. Never let a
      // stale persisted value overwrite a state the user has just chosen.
      if (!_explicitStateSet) {
        state = prefs.getBool(storageKey) ?? false;
      }
    } catch (_) {
      // An unreadable store simply starts at the welcome screen.
    }
    return state;
  }

  /// Makes the persisted guest decision authoritative before a protected
  /// operation starts. This closes the cold-start race where a user can tap
  /// Google before the async notifier restoration has completed.
  Future<bool> ensureRestored() async {
    if (state) return true;
    return restore();
  }

  Future<void> start() => _set(true);

  /// Ends guest mode. Local guest records stay where they are until an explicit
  /// migration/retirement action has completed.
  Future<void> end() => _set(false);

  Future<void> _set(bool value) async {
    _explicitStateSet = true;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, value);
    } catch (_) {
      // Persistence failure must not break the in-session choice.
    }
  }
}

final guestSessionProvider =
    NotifierProvider<GuestSessionNotifier, bool>(GuestSessionNotifier.new);

/// Blocks the normal account ledger while a guest-to-account upgrade is
/// awaiting the user's explicit data decision.
///
/// Firebase may report the newly authenticated account before the migration
/// choice is made. Keeping this barrier true makes [activeUserIdProvider]
/// continue to expose the guest ledger until merge/use-account/cancel finishes.
class GuestUpgradePendingNotifier extends Notifier<bool> {
  static const String storageKey = 'qaza_guest_upgrade_pending';
  bool _explicitStateSet = false;

  @override
  bool build() {
    Future.microtask(restore);
    return false;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_explicitStateSet) {
        state = prefs.getBool(storageKey) ?? false;
      }
    } catch (_) {
      // An unreadable marker leaves the normal session behavior intact.
    }
  }

  Future<void> setPending(bool value) async {
    _explicitStateSet = true;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, value);
    } catch (_) {
      // The in-memory barrier remains active even if persistence fails.
    }
  }
}

final guestUpgradePendingProvider =
    NotifierProvider<GuestUpgradePendingNotifier, bool>(
  GuestUpgradePendingNotifier.new,
);
