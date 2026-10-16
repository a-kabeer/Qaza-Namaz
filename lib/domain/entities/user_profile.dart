class UserProfile {
  const UserProfile({
    this.languageCode = 'en',
    this.dailyQazaTarget = defaultDailyQazaTarget,
    this.gender,
    this.madhab,
    this.dateOfBirth,
    this.pubertyAge,
    DateTime? pubertyDateOverride,
    DateTime? pubertyDate,
    ProfileInputMode? pubertyInputMode,
    this.startPrayingAge,
    DateTime? startPrayingDateOverride,
    DateTime? startPrayingDate,
    ProfileInputMode? startPrayingInputMode,
    this.isNewMuslim = false,
    this.islamAcceptanceDate,
    this.witrIncluded,
    this.onboardingCompleted = false,
    this.schemaVersion = currentSchemaVersion,
  })  : pubertyDateOverride = pubertyDateOverride ?? pubertyDate,
        pubertyInputMode = pubertyInputMode ??
            ((pubertyDateOverride ?? pubertyDate) == null
                ? ProfileInputMode.ageEstimate
                : ProfileInputMode.rememberedDate),
        startPrayingDateOverride =
            startPrayingDateOverride ?? startPrayingDate,
        startPrayingInputMode = startPrayingInputMode ??
            ((startPrayingDateOverride ?? startPrayingDate) == null
                ? ProfileInputMode.ageEstimate
                : ProfileInputMode.rememberedDate);

  /// Schema 4 includes both independent input modes and new-Muslim eligibility.
  static const int currentSchemaVersion = 4;
  static const String localLedgerUserId = 'guest';
  static const int defaultDailyQazaTarget = 5;
  static const int minDailyQazaTarget = 1;
  static const int maxDailyQazaTarget = 50;
  static const List<int> dailyQazaTargetOptions = [
    1,
    2,
    3,
    5,
    10,
    15,
    20,
    30,
    50,
  ];

  static int normalizeDailyQazaTarget(int value) =>
      value.clamp(minDailyQazaTarget, maxDailyQazaTarget).toInt();

  /// Legacy compatibility field only.
  ///
  /// Presentation language is persisted by [LocaleNotifier] through
  /// SharedPreferences and is not part of business-state persistence.
  @Deprecated('Presentation language is not business profile state.')
  final String languageCode;
  final int dailyQazaTarget;
  final Gender? gender;
  final Madhab? madhab;
  final DateTime? dateOfBirth;
  final int? pubertyAge;
  final DateTime? pubertyDateOverride;
  final ProfileInputMode pubertyInputMode;
  final int? startPrayingAge;
  final DateTime? startPrayingDateOverride;
  final ProfileInputMode startPrayingInputMode;
  final bool isNewMuslim;
  final DateTime? islamAcceptanceDate;
  final bool? witrIncluded;
  final bool onboardingCompleted;
  final int schemaVersion;

  /// Compatibility aliases for data written by the new-Muslim feature branch.
  DateTime? get pubertyDate => pubertyDateOverride;
  DateTime? get startPrayingDate => startPrayingDateOverride;

  bool get isComplete =>
      onboardingCompleted &&
      gender != null &&
      madhab != null &&
      dateOfBirth != null &&
      (!isNewMuslim || islamAcceptanceDate != null) &&
      ((isNewMuslim && islamAcceptanceDate != null) ||
          (pubertyInputMode == ProfileInputMode.ageEstimate
              ? pubertyAge != null
              : pubertyDateOverride != null)) &&
      (startPrayingInputMode == ProfileInputMode.ageEstimate
          ? startPrayingAge != null
          : startPrayingDateOverride != null) &&
      witrIncluded != null;

  UserProfile copyWith({
    String? languageCode,
    int? dailyQazaTarget,
    Gender? gender,
    bool clearGender = false,
    Madhab? madhab,
    bool clearMadhab = false,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    int? pubertyAge,
    bool clearPubertyAge = false,
    DateTime? pubertyDateOverride,
    DateTime? pubertyDate,
    bool clearPubertyDateOverride = false,
    bool clearPubertyDate = false,
    ProfileInputMode? pubertyInputMode,
    int? startPrayingAge,
    bool clearStartPrayingAge = false,
    DateTime? startPrayingDateOverride,
    DateTime? startPrayingDate,
    bool clearStartPrayingDateOverride = false,
    bool clearStartPrayingDate = false,
    ProfileInputMode? startPrayingInputMode,
    bool? isNewMuslim,
    DateTime? islamAcceptanceDate,
    bool clearIslamAcceptanceDate = false,
    bool? witrIncluded,
    bool clearWitrIncluded = false,
    bool? onboardingCompleted,
    int? schemaVersion,
  }) =>
      UserProfile(
        languageCode: languageCode ?? this.languageCode,
        dailyQazaTarget: dailyQazaTarget == null
            ? this.dailyQazaTarget
            : normalizeDailyQazaTarget(dailyQazaTarget),
        gender: clearGender ? null : gender ?? this.gender,
        madhab: clearMadhab ? null : madhab ?? this.madhab,
        dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
        pubertyAge: clearPubertyAge ? null : pubertyAge ?? this.pubertyAge,
        pubertyDateOverride:
            clearPubertyDateOverride || clearPubertyDate
                ? null
                : pubertyDateOverride ?? pubertyDate ?? this.pubertyDateOverride,
        pubertyInputMode: pubertyInputMode ?? this.pubertyInputMode,
        startPrayingAge: clearStartPrayingAge
            ? null
            : startPrayingAge ?? this.startPrayingAge,
        startPrayingDateOverride:
            clearStartPrayingDateOverride || clearStartPrayingDate
                ? null
                : startPrayingDateOverride ??
                    startPrayingDate ??
                    this.startPrayingDateOverride,
        startPrayingInputMode:
            startPrayingInputMode ?? this.startPrayingInputMode,
        isNewMuslim: isNewMuslim ?? this.isNewMuslim,
        islamAcceptanceDate: clearIslamAcceptanceDate
            ? null
            : islamAcceptanceDate ?? this.islamAcceptanceDate,
        witrIncluded:
            clearWitrIncluded ? null : witrIncluded ?? this.witrIncluded,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  /// Serializes business profile state only.
  ///
  /// Presentation language is owned by SharedPreferences and is therefore
  /// intentionally excluded from the portable/domain profile payload.
  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'dailyQazaTarget': dailyQazaTarget,
        'gender': gender?.name,
        'madhab': madhab?.name,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'pubertyAge': pubertyAge,
        'pubertyInputMode': pubertyInputMode.name,
        'pubertyDateOverride': pubertyDateOverride?.toIso8601String(),
        // Keep the legacy aliases in serialized data for safe migration.
        'pubertyDate': pubertyDateOverride?.toIso8601String(),
        'startPrayingAge': startPrayingAge,
        'startPrayingInputMode': startPrayingInputMode.name,
        'startPrayingDateOverride': startPrayingDateOverride?.toIso8601String(),
        'startPrayingDate': startPrayingDateOverride?.toIso8601String(),
        'isNewMuslim': isNewMuslim,
        'islamAcceptanceDate': islamAcceptanceDate?.toIso8601String(),
        'witrIncluded': witrIncluded,
        'onboardingCompleted': onboardingCompleted,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    Gender? parseGender(String? value) =>
        Gender.values.where((item) => item.name == value).firstOrNull;
    Madhab? parseMadhab(String? value) =>
        Madhab.values.where((item) => item.name == value).firstOrNull;
    ProfileInputMode? parseInputMode(String? value) {
      if (value == 'rememberedDate' || value == 'rememberDate') {
        return ProfileInputMode.rememberedDate;
      }
      if (value == 'ageEstimate' || value == 'estimateAge') {
        return ProfileInputMode.ageEstimate;
      }
      return null;
    }

    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return UserProfile(
      languageCode: (json['languageCode'] as String?)?.trim().isNotEmpty == true
          ? json['languageCode'] as String
          : 'en',
      dailyQazaTarget: normalizeDailyQazaTarget(
        (json['dailyQazaTarget'] as num?)?.toInt() ?? defaultDailyQazaTarget,
      ),
      gender: parseGender(json['gender'] as String?),
      madhab: parseMadhab(json['madhab'] as String?),
      dateOfBirth: parseDate(json['dateOfBirth']),
      pubertyAge: (json['pubertyAge'] as num?)?.toInt(),
      pubertyInputMode: parseInputMode(json['pubertyInputMode'] as String?),
      pubertyDateOverride:
          parseDate(json['pubertyDateOverride'] ?? json['pubertyDate']),
      startPrayingAge: (json['startPrayingAge'] as num?)?.toInt(),
      startPrayingInputMode:
          parseInputMode(json['startPrayingInputMode'] as String?),
      startPrayingDateOverride: parseDate(
        json['startPrayingDateOverride'] ?? json['startPrayingDate'],
      ),
      isNewMuslim: json['isNewMuslim'] as bool? ?? false,
      islamAcceptanceDate: parseDate(json['islamAcceptanceDate']),
      witrIncluded: json['witrIncluded'] as bool?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }
}

enum Gender { male, female }

enum ProfileInputMode { ageEstimate, rememberedDate }

enum Madhab { hanafi, shafi, maliki, hanbali, other }
