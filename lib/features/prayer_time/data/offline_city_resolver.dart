import 'package:flutter/services.dart';
import 'package:geonames_offline/geonames_offline.dart';
import 'package:timezone/timezone.dart' as tz;

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

    final timezoneId = deviceTimezoneId.trim();
    if (timezoneId.isEmpty) {
      throw const PrayerLocationException(
        'The device did not provide a valid IANA timezone.',
      );
    }
    try {
      tz.getLocation(timezoneId);
    } catch (_) {
      throw const PrayerLocationException(
        'The device did not provide a supported IANA timezone.',
      );
    }

    final place = nearest.place;
    final countryCode = place.countryCode.trim();
    if (countryCode.isEmpty) {
      throw const PrayerLocationException('City match has no country code.');
    }

    return PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      city: place.name,
      region: place.admin1Name ?? '',
      country: place.countryName,
      countryCode: countryCode,
      timezoneId: timezoneId,
      source: PrayerLocationSource.current,
      geonameId: place.geonameId,
    );
  }
}

String _normalizeSearchText(String value) {
  final lower = value.trim().toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'ǎ': 'a',
    'ǟ': 'a',
    'æ': 'ae',
    'ç': 'c',
    'ć': 'c',
    'ĉ': 'c',
    'ċ': 'c',
    'č': 'c',
    'ď': 'd',
    'đ': 'd',
    'ð': 'd',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ĕ': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ğ': 'g',
    'ĝ': 'g',
    'ġ': 'g',
    'ģ': 'g',
    'ĥ': 'h',
    'ħ': 'h',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ĩ': 'i',
    'ī': 'i',
    'ĭ': 'i',
    'į': 'i',
    'ı': 'i',
    'ĳ': 'ij',
    'ĵ': 'j',
    'ķ': 'k',
    'ĺ': 'l',
    'ļ': 'l',
    'ľ': 'l',
    'ŀ': 'l',
    'ł': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ņ': 'n',
    'ň': 'n',
    'ŋ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ŏ': 'o',
    'ő': 'o',
    'œ': 'oe',
    'ŕ': 'r',
    'ŗ': 'r',
    'ř': 'r',
    'ś': 's',
    'ŝ': 's',
    'ş': 's',
    'š': 's',
    'ß': 'ss',
    'ţ': 't',
    'ť': 't',
    'ŧ': 't',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ũ': 'u',
    'ū': 'u',
    'ŭ': 'u',
    'ů': 'u',
    'ű': 'u',
    'ų': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ŷ': 'y',
    'ž': 'z',
    'ź': 'z',
    'ż': 'z',
  };

  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

class OfflineCityCatalog {
  OfflineCityCatalog({String assetPath = _defaultAssetPath})
      : _assetPath = assetPath;

  static const String _defaultAssetPath =
      'assets/data/geonames_cities15000.tsv';

  final String _assetPath;
  List<CityOption>? _cities;
  Map<String, String>? _countryNames;

  Future<void> load() async {
    if (_cities != null) return;

    final raw = await rootBundle.loadString(_assetPath);
    final lines = raw.split('\n');
    final cities = <CityOption>[];
    final countries = <String, String>{};

    for (var index = 1; index < lines.length; index++) {
      final line = lines[index].trimRight();
      if (line.isEmpty) continue;

      final fields = line.split('\t');
      if (fields.length != 8) continue;

      final geonameId = int.tryParse(fields[0]);
      final city = fields[1].trim();
      final region = fields[2].trim();
      final country = fields[3].trim();
      final countryCode = fields[4].trim().toUpperCase();
      final latitude = double.tryParse(fields[5]);
      final longitude = double.tryParse(fields[6]);
      final timezoneId = fields[7].trim();

      if (geonameId == null ||
          city.isEmpty ||
          countryCode.isEmpty ||
          latitude == null ||
          longitude == null ||
          timezoneId.isEmpty) {
        continue;
      }

      cities.add(
        CityOption(
          geonameId: geonameId,
          city: city,
          region: region,
          country: country,
          countryCode: countryCode,
          timezoneId: timezoneId,
          latitude: latitude,
          longitude: longitude,
        ),
      );
      countries.putIfAbsent(countryCode, () => country);
    }

    cities.sort((a, b) {
      final byCountry = a.countryCode.compareTo(b.countryCode);
      if (byCountry != 0) return byCountry;

      final byCity = a.city.toLowerCase().compareTo(b.city.toLowerCase());
      if (byCity != 0) return byCity;

      return a.geonameId.compareTo(b.geonameId);
    });

    _cities = List.unmodifiable(cities);
    _countryNames = Map.unmodifiable(countries);
  }

  List<String> countryCodes() {
    final names = _countryNames;
    if (names == null) {
      throw StateError('OfflineCityCatalog.load() must be called first.');
    }
    final codes = names.keys.toList()..sort();
    return List.unmodifiable(codes);
  }

  String countryName(String countryCode) {
    final names = _countryNames;
    if (names == null) {
      throw StateError('OfflineCityCatalog.load() must be called first.');
    }
    return names[countryCode.toUpperCase()] ?? countryCode.toUpperCase();
  }

  List<CityOption> citiesForCountry(String countryCode, {String query = ''}) {
    final cities = _cities;
    if (cities == null) {
      throw StateError('OfflineCityCatalog.load() must be called first.');
    }

    final normalizedCountry = countryCode.toUpperCase();
    final normalizedQuery = _normalizeSearchText(query);

    final result = cities.where((city) {
      if (city.countryCode != normalizedCountry) return false;
      if (normalizedQuery.isEmpty) return true;

      return _normalizeSearchText(city.city).contains(normalizedQuery) ||
          _normalizeSearchText(city.region).contains(normalizedQuery);
    }).toList(growable: false);

    return List.unmodifiable(result);
  }
}
