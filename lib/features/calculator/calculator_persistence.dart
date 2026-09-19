import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CalculatorSnapshot {
  const CalculatorSnapshot({
    required this.step,
    required this.dob,
    required this.balighMode,
    required this.balighAge,
    required this.balighDate,
    required this.prayerStartMode,
    required this.prayerStartAge,
    required this.prayerStartDate,
    required this.includeWitr,
    required this.hasCalculation,
  });

  final int step;
  final DateTime? dob;
  final String balighMode;
  final int balighAge;
  final DateTime? balighDate;
  final String prayerStartMode;
  final int prayerStartAge;
  final DateTime? prayerStartDate;
  final bool includeWitr;
  final bool hasCalculation;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'step': step,
        'dob': dob?.toIso8601String(),
        'balighMode': balighMode,
        'balighAge': balighAge,
        'balighDate': balighDate?.toIso8601String(),
        'prayerStartMode': prayerStartMode,
        'prayerStartAge': prayerStartAge,
        'prayerStartDate': prayerStartDate?.toIso8601String(),
        'includeWitr': includeWitr,
        'hasCalculation': hasCalculation,
      };

  factory CalculatorSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version != 1) {
      throw StateError(
          'Unsupported calculator snapshot schema version $version.');
    }
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    final savedStep = (json['step'] as num?)?.toInt() ?? 0;
    return CalculatorSnapshot(
      step: savedStep.clamp(0, 2).toInt(),
      dob: parseDate(json['dob']),
      balighMode: json['balighMode'] as String? ?? 'age',
      balighAge: (json['balighAge'] as num?)?.toInt() ?? 12,
      balighDate: parseDate(json['balighDate']),
      prayerStartMode: json['prayerStartMode'] as String? ?? 'age',
      prayerStartAge: (json['prayerStartAge'] as num?)?.toInt() ?? 18,
      prayerStartDate: parseDate(json['prayerStartDate']),
      includeWitr: json['includeWitr'] as bool? ?? false,
      hasCalculation: json['hasCalculation'] as bool? ?? false,
    );
  }
}

class CalculatorPersistence {
  const CalculatorPersistence({this.storagePrefix = defaultStoragePrefix});

  static const String defaultStoragePrefix = 'qaza_calculator_v1';
  final String storagePrefix;

  String keyForUser(String? userId) =>
      '${storagePrefix}_${userId == null || userId.isEmpty ? 'anonymous' : userId}';

  Future<CalculatorSnapshot?> load(
      {String? userId, SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(keyForUser(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return CalculatorSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } on StateError {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    CalculatorSnapshot snapshot, {
    String? userId,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(keyForUser(userId), jsonEncode(snapshot.toJson()));
  }

  Future<void> clear({String? userId, SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(keyForUser(userId));
  }
}
