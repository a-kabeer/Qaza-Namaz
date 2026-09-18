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
/// migrated first and are never deleted by it.
class GuestSessionNotifier extends Notifier<bool> {
  static const String storageKey = 'qaza_guest_mode';

  @override
  bool build() {
    Future.microtask(restore);
    return false;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(storageKey) ?? false) state = true;
    } catch (_) {
      // An unreadable store simply starts at the welcome screen.
    }
  }

  Future<void> start() => _set(true);

  /// Ends guest mode. Local guest records stay where they are.
  Future<void> end() => _set(false);

  Future<void> _set(bool value) async {
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
