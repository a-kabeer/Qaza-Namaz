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
    UserProfile? existing;
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        existing = UserProfile.fromJson(
          jsonDecode(existingRaw) as Map<String, dynamic>,
        );
      } catch (_) {
        existing = null;
      }
    }

    final snapshots = <Map<String, dynamic>>[];
    final legacyKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_calculatorPrefix))
        .toList()
      ..sort();
    for (final key in legacyKeys) {
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

    // A legacy install normally has one active snapshot. Stable ordering keeps
    // migration deterministic if more than one legacy calculator snapshot exists.
    final snapshot = snapshots.first;
    final locale = prefs.getString('qaza_locale');
    final dob = _parseDate(snapshot['dob']);
    final balighMode = snapshot['balighMode'] as String? ?? 'age';
    final prayerStartMode = snapshot['prayerStartMode'] as String? ?? 'age';
    final oldPuberty =
        balighMode == 'age' ? (snapshot['balighAge'] as num?)?.toInt() : null;
    final oldPrayerStart = prayerStartMode == 'age'
        ? (snapshot['prayerStartAge'] as num?)?.toInt()
        : null;
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

    final migratedPuberty = switch (existing?.gender) {
      Gender.male => oldPuberty != null && oldPuberty >= 12 && oldPuberty <= 15
          ? oldPuberty
          : null,
      Gender.female => oldPuberty != null && oldPuberty >= 9 && oldPuberty <= 15
          ? oldPuberty
          : null,
      null =>
        // Without a known gender, preserve only values valid for both new
        // profile ranges rather than inventing a gender.
        oldPuberty != null && oldPuberty >= 12 && oldPuberty <= 15
            ? oldPuberty
            : null,
    };

    final profile = UserProfile(
      languageCode:
          existing?.languageCode ?? LocaleCodeValidator.normalize(locale),
      gender: existing?.gender,
      madhab: existing?.madhab ?? (oldWitr == null ? null : Madhab.other),
      dateOfBirth: existing?.dateOfBirth ?? dob,
      pubertyAge: existing?.pubertyAge ?? migratedPuberty,
      startPrayingAge: existing?.startPrayingAge ?? startAge,
      witrIncluded: existing?.witrIncluded ?? oldWitr,
      onboardingCompleted: existing?.onboardingCompleted ?? false,
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
