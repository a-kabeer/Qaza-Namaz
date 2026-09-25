import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

class SharedPreferencesUserProfileRepository implements UserProfileRepository {
  const SharedPreferencesUserProfileRepository({this.preferences});
  final SharedPreferences? preferences;

  @override
  Future<UserProfile?> load() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(UserProfile.storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(UserProfile.storageKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(UserProfile.storageKey);
  }
}
