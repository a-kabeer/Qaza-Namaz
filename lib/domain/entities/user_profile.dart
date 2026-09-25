
class UserProfile {
  const UserProfile({
    this.languageCode = 'en',
    this.gender,
    this.madhab,
    this.dateOfBirth,
    this.pubertyAge,
    this.startPrayingAge,
    this.witrIncluded,
    this.onboardingCompleted = false,
    this.schemaVersion = 1,
  });

  static const int currentSchemaVersion = 1;
  static const String storageKey = 'qaza_user_profile_v1';
  static const String localLedgerUserId = 'guest';

  final String languageCode;
  final Gender? gender;
  final Madhab? madhab;
  final DateTime? dateOfBirth;
  final int? pubertyAge;
  final int? startPrayingAge;
  final bool? witrIncluded;
  final bool onboardingCompleted;
  final int schemaVersion;

  bool get isComplete =>
      onboardingCompleted &&
      gender != null &&
      madhab != null &&
      dateOfBirth != null &&
      pubertyAge != null &&
      startPrayingAge != null &&
      witrIncluded != null;

  UserProfile copyWith({
    String? languageCode,
    Gender? gender,
    bool clearGender = false,
    Madhab? madhab,
    bool clearMadhab = false,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    int? pubertyAge,
    bool clearPubertyAge = false,
    int? startPrayingAge,
    bool clearStartPrayingAge = false,
    bool? witrIncluded,
    bool clearWitrIncluded = false,
    bool? onboardingCompleted,
    int? schemaVersion,
  }) =>
      UserProfile(
        languageCode: languageCode ?? this.languageCode,
        gender: clearGender ? null : gender ?? this.gender,
        madhab: clearMadhab ? null : madhab ?? this.madhab,
        dateOfBirth:
            clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
        pubertyAge: clearPubertyAge ? null : pubertyAge ?? this.pubertyAge,
        startPrayingAge: clearStartPrayingAge
            ? null
            : startPrayingAge ?? this.startPrayingAge,
        witrIncluded:
            clearWitrIncluded ? null : witrIncluded ?? this.witrIncluded,
        onboardingCompleted:
            onboardingCompleted ?? this.onboardingCompleted,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'languageCode': languageCode,
        'gender': gender?.name,
        'madhab': madhab?.name,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'pubertyAge': pubertyAge,
        'startPrayingAge': startPrayingAge,
        'witrIncluded': witrIncluded,
        'onboardingCompleted': onboardingCompleted,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    Gender? parseGender(String? value) =>
        Gender.values.where((item) => item.name == value).firstOrNull;
    Madhab? parseMadhab(String? value) =>
        Madhab.values.where((item) => item.name == value).firstOrNull;
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return UserProfile(
      languageCode: (json['languageCode'] as String?)?.trim().isNotEmpty == true
          ? json['languageCode'] as String
          : 'en',
      gender: parseGender(json['gender'] as String?),
      madhab: parseMadhab(json['madhab'] as String?),
      dateOfBirth: parseDate(json['dateOfBirth']),
      pubertyAge: (json['pubertyAge'] as num?)?.toInt(),
      startPrayingAge: (json['startPrayingAge'] as num?)?.toInt(),
      witrIncluded: json['witrIncluded'] as bool?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }
}

enum Gender { male, female }

enum Madhab { hanafi, shafi, maliki, hanbali, other }
