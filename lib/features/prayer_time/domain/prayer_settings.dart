enum PrayerCalculationMethod {
  karachi,
  muslimWorldLeague,
  isna,
  makkah,
  egypt,
  tehran,
  custom,
}

enum PrayerAsrMethod { standard, hanafi }

enum PrayerHighLatitudeRule {
  automatic,
  middleOfTheNight,
  seventhOfTheNight,
  twilightAngle,
}

class PrayerSettings {
  const PrayerSettings({
    this.calculationMethod = PrayerCalculationMethod.karachi,
    this.asrMethod = PrayerAsrMethod.hanafi,
    this.highLatitudeRule = PrayerHighLatitudeRule.automatic,
    this.fajrAngle = 18.0,
    this.ishaAngle = 18.0,
    this.adjustments = const <String, int>{},
    this.use24HourFormat = false,
  });

  final PrayerCalculationMethod calculationMethod;
  final PrayerAsrMethod asrMethod;
  final PrayerHighLatitudeRule highLatitudeRule;
  final double fajrAngle;
  final double ishaAngle;
  final Map<String, int> adjustments;
  final bool use24HourFormat;

  PrayerSettings copyWith({
    PrayerCalculationMethod? calculationMethod,
    PrayerAsrMethod? asrMethod,
    PrayerHighLatitudeRule? highLatitudeRule,
    double? fajrAngle,
    double? ishaAngle,
    Map<String, int>? adjustments,
    bool? use24HourFormat,
  }) {
    return PrayerSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrMethod: asrMethod ?? this.asrMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      fajrAngle: fajrAngle ?? this.fajrAngle,
      ishaAngle: ishaAngle ?? this.ishaAngle,
      adjustments: adjustments ?? this.adjustments,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
    );
  }

  Map<String, dynamic> toJson() => {
        'calculationMethod': calculationMethod.name,
        'asrMethod': asrMethod.name,
        'highLatitudeRule': highLatitudeRule.name,
        'fajrAngle': fajrAngle,
        'ishaAngle': ishaAngle,
        'adjustments': adjustments,
        'use24HourFormat': use24HourFormat,
      };

  static PrayerSettings fromJson(Map<String, dynamic> json) {
    final method = PrayerCalculationMethod.values.firstWhere(
      (item) => item.name == json['calculationMethod'],
      orElse: () => PrayerCalculationMethod.karachi,
    );
    final asr = PrayerAsrMethod.values.firstWhere(
      (item) => item.name == json['asrMethod'],
      orElse: () => PrayerAsrMethod.hanafi,
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
      asrMethod: asr,
      highLatitudeRule: high,
      fajrAngle: (json['fajrAngle'] as num?)?.toDouble() ?? 18.0,
      ishaAngle: (json['ishaAngle'] as num?)?.toDouble() ?? 18.0,
      adjustments: adjustments,
      use24HourFormat: json['use24HourFormat'] as bool? ?? false,
    );
  }
}
