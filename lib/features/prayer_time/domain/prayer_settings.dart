enum PrayerCalculationMethod {
  karachi,
  muslimWorldLeague,
  isna,
  makkah,
  egypt,
  tehran,
  custom,
}


enum PrayerHighLatitudeRule {
  automatic,
  middleOfTheNight,
  seventhOfTheNight,
  twilightAngle,
}

/// Internal application-owned Prayer Time calculation defaults.
/// Asr and display format are resolved outside this object.
class PrayerSettings {
  const PrayerSettings({
    this.calculationMethod = PrayerCalculationMethod.karachi,
    this.highLatitudeRule = PrayerHighLatitudeRule.automatic,
    this.fajrAngle = 18.0,
    this.ishaAngle = 18.0,
    this.adjustments = const <String, int>{},
  });

  final PrayerCalculationMethod calculationMethod;
  final PrayerHighLatitudeRule highLatitudeRule;
  final double fajrAngle;
  final double ishaAngle;
  final Map<String, int> adjustments;

  PrayerSettings copyWith({
    PrayerCalculationMethod? calculationMethod,
    PrayerHighLatitudeRule? highLatitudeRule,
    double? fajrAngle,
    double? ishaAngle,
    Map<String, int>? adjustments,
  }) {
    return PrayerSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      fajrAngle: fajrAngle ?? this.fajrAngle,
      ishaAngle: ishaAngle ?? this.ishaAngle,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  Map<String, dynamic> toJson() => {
        'calculationMethod': calculationMethod.name,
        'highLatitudeRule': highLatitudeRule.name,
        'fajrAngle': fajrAngle,
        'ishaAngle': ishaAngle,
        'adjustments': adjustments,
      };

  /// Reads the current shape and ignores legacy user preference fields.
  static PrayerSettings fromJson(Map<String, dynamic> json) {
    final method = PrayerCalculationMethod.values.firstWhere(
      (item) => item.name == json['calculationMethod'],
      orElse: () => PrayerCalculationMethod.karachi,
    );
    final high = PrayerHighLatitudeRule.values.firstWhere(
      (item) => item.name == json['highLatitudeRule'],
      orElse: () => PrayerHighLatitudeRule.automatic,
    );
    final raw = json['adjustments'];
    final adjustments = <String, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value is num) {
          adjustments[entry.key.toString()] = (entry.value as num).round();
        }
      }
    }
    return PrayerSettings(
      calculationMethod: method,
      highLatitudeRule: high,
      fajrAngle: (json['fajrAngle'] as num?)?.toDouble() ?? 18.0,
      ishaAngle: (json['ishaAngle'] as num?)?.toDouble() ?? 18.0,
      adjustments: adjustments,
    );
  }
}
