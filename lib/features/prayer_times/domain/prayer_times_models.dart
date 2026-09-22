import 'dart:convert';

enum PrayerName {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

extension PrayerNameX on PrayerName {
  String get apiKey => switch (this) {
        PrayerName.fajr => 'Fajr',
        PrayerName.sunrise => 'Sunrise',
        PrayerName.dhuhr => 'Dhuhr',
        PrayerName.asr => 'Asr',
        PrayerName.maghrib => 'Maghrib',
        PrayerName.isha => 'Isha',
      };

  String get cacheKey => name;

  bool get isCyclePrayer =>
      this == PrayerName.fajr ||
      this == PrayerName.dhuhr ||
      this == PrayerName.asr ||
      this == PrayerName.maghrib ||
      this == PrayerName.isha;
}

enum LocationSource { device, manualCity, manualCoordinates }

enum LocationAccuracyKind { unknown, approximate, precise }

enum AsrMethod {
  standard,
  hanafi,
}

enum CalculationMethod {
  recommended,
  jafari,
  karachi,
  isna,
  mwl,
  makkah,
  egyptian,
  tehran,
  gulf,
  kuwait,
  qatar,
  singapore,
  france,
  turkey,
  russia,
  moonsighting,
  dubai,
  jakim,
  tunisia,
  algeria,
  kemenag,
  morocco,
  portugal,
  jordan,
}

extension CalculationMethodX on CalculationMethod {
  String get storageValue => name;

  static CalculationMethod fromStorage(String? value) {
    return CalculationMethod.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CalculationMethod.recommended,
    );
  }
}

class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    this.country,
    this.city,
    this.region,
    this.countryCode,
    this.timezone,
    this.source = LocationSource.manualCoordinates,
    this.accuracyMeters,
    this.accuracyKind = LocationAccuracyKind.unknown,
  });

  final double latitude;
  final double longitude;
  final String? country;
  final String? city;
  final String? region;
  final String? countryCode;
  final String? timezone;
  final LocationSource source;
  final double? accuracyMeters;
  final LocationAccuracyKind accuracyKind;

  PrayerLocation copyWith({
    double? latitude,
    double? longitude,
    String? country,
    String? city,
    String? region,
    String? countryCode,
    String? timezone,
    LocationSource? source,
    double? accuracyMeters,
    LocationAccuracyKind? accuracyKind,
  }) {
    return PrayerLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      country: country ?? this.country,
      city: city ?? this.city,
      region: region ?? this.region,
      countryCode: countryCode ?? this.countryCode,
      timezone: timezone ?? this.timezone,
      source: source ?? this.source,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      accuracyKind: accuracyKind ?? this.accuracyKind,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'country': country,
        'city': city,
        'region': region,
        'countryCode': countryCode,
        'timezone': timezone,
        'source': source.name,
        'accuracyMeters': accuracyMeters,
        'accuracyKind': accuracyKind.name,
      };

  factory PrayerLocation.fromJson(Map<String, dynamic> json) {
    return PrayerLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      countryCode: json['countryCode'] as String?,
      timezone: json['timezone'] as String?,
      source: LocationSource.values.firstWhere(
        (item) => item.name == json['source'],
        orElse: () => LocationSource.manualCoordinates,
      ),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      accuracyKind: LocationAccuracyKind.values.firstWhere(
        (item) => item.name == json['accuracyKind'],
        orElse: () => LocationAccuracyKind.unknown,
      ),
    );
  }

  String get cacheIdentity {
    final lat = latitude.toStringAsFixed(6);
    final lon = longitude.toStringAsFixed(6);
    return '${lat},${lon}';
  }

  String get displayName {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!,
      if (region != null && region!.trim().isNotEmpty && region != city) region!,
      if (country != null && country!.trim().isNotEmpty) country!,
    ];
    return parts.isEmpty
        ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
        : parts.join(', ');
  }
}

class PrayerSettings {
  const PrayerSettings({
    this.calculationMethod = CalculationMethod.recommended,
    this.asrMethod = AsrMethod.standard,
  });

  final CalculationMethod calculationMethod;
  final AsrMethod asrMethod;

  PrayerSettings copyWith({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
  }) {
    return PrayerSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrMethod: asrMethod ?? this.asrMethod,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'calculationMethod': calculationMethod.storageValue,
        'asrMethod': asrMethod.name,
      };

  factory PrayerSettings.fromJson(Map<String, dynamic> json) {
    return PrayerSettings(
      calculationMethod:
          CalculationMethodX.fromStorage(json['calculationMethod'] as String?),
      asrMethod: AsrMethod.values.firstWhere(
        (item) => item.name == json['asrMethod'],
        orElse: () => AsrMethod.standard,
      ),
    );
  }
}

class PrayerTime {
  const PrayerTime({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hour': hour,
        'minute': minute,
      };

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }
}

class HijriDate {
  const HijriDate({
    required this.day,
    required this.month,
    required this.year,
  });

  final int day;
  final String month;
  final int year;

  String get display => '$day $month $year AH';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day': day,
        'month': month,
        'year': year,
      };

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      day: json['day'] as int,
      month: json['month'] as String,
      year: json['year'] as int,
    );
  }
}

class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.timezone,
    required this.times,
    required this.solarNoon,
    required this.sunset,
    required this.hijriDate,
    required this.fetchedAt,
    this.resolvedCalculationMethodName,
  });

  final DateTime date;
  final String timezone;
  final Map<PrayerName, PrayerTime> times;
  final DateTime solarNoon;
  final DateTime sunset;
  final HijriDate hijriDate;
  final DateTime fetchedAt;
  final String? resolvedCalculationMethodName;

  PrayerDay copyWith({
    DateTime? date,
    String? timezone,
    Map<PrayerName, PrayerTime>? times,
    DateTime? solarNoon,
    DateTime? sunset,
    HijriDate? hijriDate,
    DateTime? fetchedAt,
    String? resolvedCalculationMethodName,
  }) {
    return PrayerDay(
      date: date ?? this.date,
      timezone: timezone ?? this.timezone,
      times: times ?? this.times,
      solarNoon: solarNoon ?? this.solarNoon,
      sunset: sunset ?? this.sunset,
      hijriDate: hijriDate ?? this.hijriDate,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      resolvedCalculationMethodName:
          resolvedCalculationMethodName ?? this.resolvedCalculationMethodName,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'timezone': timezone,
        'times': <String, dynamic>{
          for (final entry in times.entries)
            entry.key.cacheKey: entry.value.toJson(),
        },
        'solarNoon': solarNoon.toIso8601String(),
        'sunset': sunset.toIso8601String(),
        'hijriDate': hijriDate.toJson(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'resolvedCalculationMethodName': resolvedCalculationMethodName,
      };

  factory PrayerDay.fromJson(Map<String, dynamic> json) {
    final rawTimes = Map<String, dynamic>.from(json['times'] as Map);
    final times = <PrayerName, PrayerTime>{};
    for (final prayer in PrayerName.values) {
      final raw = rawTimes[prayer.cacheKey];
      if (raw is Map) {
        times[prayer] = PrayerTime.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    return PrayerDay(
      date: DateTime.parse(json['date'] as String),
      timezone: json['timezone'] as String,
      times: times,
      solarNoon: DateTime.parse(json['solarNoon'] as String),
      sunset: DateTime.parse(json['sunset'] as String),
      hijriDate: HijriDate.fromJson(
        Map<String, dynamic>.from(json['hijriDate'] as Map),
      ),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      resolvedCalculationMethodName:
          json['resolvedCalculationMethodName'] as String?,
    );
  }
}

class PrayerTimesRequest {
  const PrayerTimesRequest({
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.method,
    required this.asrMethod,
    this.timezone,
  });

  final double latitude;
  final double longitude;
  final DateTime date;
  final CalculationMethod method;
  final AsrMethod asrMethod;
  final String? timezone;

  String get cacheKey {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}_${dateKey}_${method.storageValue}_${asrMethod.name}';
  }
}

String encodePrayerCache(Map<String, dynamic> data) => jsonEncode(data);
