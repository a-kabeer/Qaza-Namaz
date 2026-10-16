class UserProfile {
  const UserProfile({
    this.languageCode = 'en',
    this.dailyQazaTarget = defaultDailyQazaTarget,
    this.gender,
    this.madhab,
    this.dateOfBirth,
    this.pubertyAge,
    this.pubertyDate,
    this.pubertyInputMode = PubertyInputMode.estimateAge,
    this.startPrayingAge,
    this.startPrayingDate,
    this.isNewMuslim = false,
    this.islamAcceptanceDate,
    this.witrIncluded,
    this.onboardingCompleted = false,
    this.schemaVersion = currentSchemaVersion,
  });

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
  final DateTime? pubertyDate;
  final PubertyInputMode pubertyInputMode;
  final int? startPrayingAge;
  final DateTime? startPrayingDate;
  final bool isNewMuslim;
  final DateTime? islamAcceptanceDate;
  final bool? witrIncluded;
  final bool onboardingCompleted;
  final int schemaVersion;

  bool get isComplete =>
      onboardingCompleted &&
      gender != null &&
      madhab != null &&
      dateOfBirth != null &&
      (pubertyAge != null ||
          pubertyDate != null ||
          (isNewMuslim && islamAcceptanceDate != null)) &&
      (isNewMuslim ? startPrayingDate != null : startPrayingAge != null) &&
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
    DateTime? pubertyDate,
    bool clearPubertyDate = false,
    PubertyInputMode? pubertyInputMode,
    int? startPrayingAge,
    bool clearStartPrayingAge = false,
    DateTime? startPrayingDate,
    bool clearStartPrayingDate = false,
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
        pubertyDate: clearPubertyDate ? null : pubertyDate ?? this.pubertyDate,
        pubertyInputMode: pubertyInputMode ?? this.pubertyInputMode,
        startPrayingAge: clearStartPrayingAge
            ? null
            : startPrayingAge ?? this.startPrayingAge,
        startPrayingDate: clearStartPrayingDate
            ? null
            : startPrayingDate ?? this.startPrayingDate,
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
        'pubertyDate': pubertyDate?.toIso8601String(),
        'pubertyInputMode': pubertyInputMode.name,
        'startPrayingAge': startPrayingAge,
        'startPrayingDate': startPrayingDate?.toIso8601String(),
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
      pubertyDate: parseDate(json['pubertyDate']),
      pubertyInputMode: PubertyInputMode.values
              .where((item) => item.name == json['pubertyInputMode'])
              .firstOrNull ??
          PubertyInputMode.estimateAge,
      startPrayingAge: (json['startPrayingAge'] as num?)?.toInt(),
      startPrayingDate: parseDate(json['startPrayingDate']),
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

enum PubertyInputMode { rememberDate, estimateAge }

enum Madhab { hanafi, shafi, maliki, hanbali, other }
