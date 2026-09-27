import 'dart:math' as math;

enum PrayerLocationRequirement {
  ready,
  locationServiceDisabled,
  permissionRequired,
  permissionDenied,
  permissionDeniedForever,
}

enum PrayerLocationSetupFailure {
  locationServiceResolutionCancelled,
  permissionDenied,
  permissionDeniedForever,
}

class PrayerLocationException implements Exception {
  const PrayerLocationException(this.failure);

  final PrayerLocationSetupFailure failure;
}

enum PrayerLocationSource { current, city }

class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.region,
    required this.country,
    required this.countryCode,
    required this.timezoneId,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String region;
  final String country;
  final String countryCode;
  final String timezoneId;
  final PrayerLocationSource source;

  String get primaryLabel => city.isEmpty ? country : city;

  String get secondaryLabel {
    final parts = <String>[];
    if (region.trim().isNotEmpty && region.trim() != city.trim()) {
      parts.add(region.trim());
    }
    if (country.trim().isNotEmpty) parts.add(country.trim());
    return parts.join(', ');
  }

  String get displayName =>
      secondaryLabel.isEmpty ? primaryLabel : '$primaryLabel, $secondaryLabel';

  double distanceKmTo(double latitude, double longitude) {
    const earthRadiusKm = 6371.0;
    final lat1 = this.latitude * math.pi / 180;
    final lat2 = latitude * math.pi / 180;
    final dLat = (latitude - this.latitude) * math.pi / 180;
    final dLon = (longitude - this.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'region': region,
        'country': country,
        'countryCode': countryCode,
        'timezoneId': timezoneId,
        'source': source.name,
      };

  static PrayerLocation? fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final city = json['city'] as String?;
    final country = json['country'] as String?;
    final countryCode = json['countryCode'] as String?;
    final timezoneId = json['timezoneId'] as String?;
    final sourceName = json['source'] as String?;
    if (latitude == null ||
        longitude == null ||
        city == null ||
        country == null ||
        countryCode == null ||
        timezoneId == null ||
        sourceName == null) {
      return null;
    }
    final source = PrayerLocationSource.values.where(
      (value) => value.name == sourceName,
    );
    if (source.isEmpty) return null;
    return PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      city: city,
      region: json['region'] as String? ?? '',
      country: country,
      countryCode: countryCode,
      timezoneId: timezoneId,
      source: source.first,
    );
  }
}

class CityOption {
  const CityOption({
    required this.city,
    required this.region,
    required this.country,
    required this.countryCode,
    required this.timezoneId,
    required this.latitude,
    required this.longitude,
  });

  final String city;
  final String region;
  final String country;
  final String countryCode;
  final String timezoneId;
  final double latitude;
  final double longitude;

  String get displayName => region.trim().isEmpty
      ? '$city, $country'
      : '$city, $region, $country';
}
