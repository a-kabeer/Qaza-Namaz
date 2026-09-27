import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geonames_offline/geonames_offline.dart';
import 'package:timezone_country/timezone_country.dart';

import '../domain/prayer_location.dart';

class PrayerLocationException implements Exception {
  const PrayerLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineCityResolver {
  OfflineCityResolver({ReverseGeocoder? geocoder})
      : _geocoder = geocoder ?? GeonamesReverseGeocoder.cities15000();

  final ReverseGeocoder _geocoder;

  static const double maxAutoCityDistanceMetres = 80000;

  String get attribution => _geocoder.attribution;

  PrayerLocation resolveCurrent({
    required double latitude,
    required double longitude,
    required String deviceTimezoneId,
  }) {
    final nearest = _geocoder.nearest(latitude, longitude);
    if (nearest == null) {
      throw const PrayerLocationException(
        'No offline city match is available for this location.',
      );
    }
    if (nearest.distanceMetres > maxAutoCityDistanceMetres) {
      throw const PrayerLocationException(
        'No sufficiently close offline city match is available.',
      );
    }

    final place = nearest.place;
    final countryCode = place.countryCode;
    final countryName =
        TimezoneConvert.countryName(countryCode) ?? place.countryName;

    var timezoneId = deviceTimezoneId;
    final timezoneCountry = TimezoneConvert.timezoneToCountryCode(timezoneId);
    if (!TimezoneConvert.isKnownTimezone(timezoneId) ||
        timezoneCountry != countryCode) {
      timezoneId = TimezoneConvert.nearestTimezone(
            latitude,
            longitude,
            countryCode: countryCode,
          ) ??
          TimezoneConvert.primaryTimezone(countryCode) ??
          'Etc/UTC';
    }

    return PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      city: place.name,
      region: place.admin1Name,
      country: countryName,
      countryCode: countryCode,
      timezoneId: timezoneId,
      source: PrayerLocationSource.current,
    );
  }

  List<String> countryCodes() => List.unmodifiable(
        TimezoneConvert.allCountryCodes.where(
          TimezoneConvert.isValidCountryCode,
        ),
      );

  String countryName(String countryCode) =>
      TimezoneConvert.countryName(countryCode) ?? countryCode;

  List<CityOption> citiesForCountry(
    String countryCode, {
    String query = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final zones = TimezoneConvert.countryToTimezones(countryCode);
    final seen = <String>{};
    final options = <CityOption>[];

    for (final zone in zones) {
      final coordinates = TimezoneConvert.timezoneCoordinatesMap[zone];
      if (coordinates == null) continue;

      final city = TimezoneConvert.timezoneCity(zone) ??
          zone.split('/').last.replaceAll('_', ' ');
      final country = countryName(countryCode);
      final option = CityOption(
        city: city,
        region: '',
        country: country,
        countryCode: countryCode,
        timezoneId: zone,
        latitude: coordinates.$1,
        longitude: coordinates.$2,
      );
      final identity = city.toLowerCase() + '|' + zone;
      if (!seen.add(identity)) continue;
      if (normalizedQuery.isNotEmpty &&
          !option.displayName.toLowerCase().contains(normalizedQuery) &&
          !zone.toLowerCase().contains(normalizedQuery)) {
        continue;
      }
      options.add(option);
    }

    options.sort(
      (a, b) => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
    );
    return List.unmodifiable(options);
  }

}
