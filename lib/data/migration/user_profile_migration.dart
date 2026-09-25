import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';

class UserProfileMigration {
  const UserProfileMigration();

  static const _calculatorPrefix = 'qaza_calculator_v1_';

  Future<void> migrateLegacyCalculatorData({
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();

    final existingRaw = prefs.getString(UserProfile.storageKey);
    if (existingRaw != null && existingRaw.isNotEmpty) {
      // A completed/new profile is authoritative. Legacy calculator snapshots
      // are no longer needed once a profile exists.
      await _removeLegacySnapshots(prefs);
      return;
    }

    final snapshots = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_calculatorPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) snapshots.add(decoded);
      } catch (_) {
        // Corrupt legacy data is ignored; required profile fields will be
        // requested instead of being guessed.
      }
    }

    if (snapshots.isEmpty) return;

    // Prefer the most recently useful snapshot by iterating in stable key
    // order. A legacy app normally has one active calculator snapshot.
    final snapshot = snapshots.first;
    final locale = prefs.getString('qaza_locale');
    final dob = _parseDate(snapshot['dob']);
    final oldPuberty = (snapshot['balighAge'] as num?)?.toInt();
    final oldPrayerStart = (snapshot['prayerStartAge'] as num?)?.toInt();
    final oldWitr = snapshot['includeWitr'] as bool?;

    var startAge = oldPrayerStart;
    if (dob != null && oldPuberty != null && startAge != null) {
      final today = DateTime.now();
      final ageNow = ProfileRules.currentAge(dob, today);
      if (startAge < oldPuberty || startAge > ageNow) {
        startAge = null;
      }
    } else {
      startAge = null;
    }

    // 12–15 is the safe overlap between the new male and female ranges. Do
    // not manufacture a gender merely to preserve an old 9–11 value.
    final migratedPuberty =
        oldPuberty != null && oldPuberty >= 12 && oldPuberty <= 15
            ? oldPuberty
            : null;

    final profile = UserProfile(
      languageCode: LocaleCodeValidator.normalize(locale),
      dateOfBirth: dob,
      pubertyAge: migratedPuberty,
      startPrayingAge: startAge,
      // School of thought was not part of the legacy calculator. "Other"
      // preserves the user's old Witr choice without claiming a Madhab.
      madhab: oldWitr == null ? null : Madhab.other,
      witrIncluded: oldWitr,
      onboardingCompleted: false,
    );

    await prefs.setString(UserProfile.storageKey, jsonEncode(profile.toJson()));
    await _removeLegacySnapshots(prefs);
  }

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  Future<void> _removeLegacySnapshots(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().where(
          (key) => key.startsWith(_calculatorPrefix),
        )) {
      await prefs.remove(key);
    }
  }
}

class LocaleCodeValidator {
  static const supported = {'en', 'ur'};

  static String normalize(String? value) =>
      value != null && supported.contains(value) ? value : 'en';
}
