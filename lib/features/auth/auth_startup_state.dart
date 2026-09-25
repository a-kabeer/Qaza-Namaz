import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists that a newly-created Google account still needs the local
/// profile/Qaza setup flow to be completed.
///
/// This marker is deliberately tied to the Firebase UID. It prevents a
/// newly-created account on a fresh device from being mistaken for an
/// established account after an app restart, while leaving established
/// accounts free to go directly to Home.
class AuthStartupState {
  const AuthStartupState._();

  static const String pendingNewGoogleUserKey =
      'qaza_pending_new_google_user_id';

  static Future<void> markNewGoogleUser(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingNewGoogleUserKey, userId);
  }

  static Future<bool> isPendingFor(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(pendingNewGoogleUserKey) == userId;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingNewGoogleUserKey);
  }
}

final pendingNewGoogleUserProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, userId) => AuthStartupState.isPendingFor(userId),
);
