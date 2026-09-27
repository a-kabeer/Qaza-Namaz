import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/prayer_location.dart';
import 'offline_city_resolver.dart';

class PrayerLocationRepository {
  const PrayerLocationRepository(this._resolver);

  final OfflineCityResolver _resolver;

  Future<PrayerLocation?> getLastKnown() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final timezone = await FlutterTimezone.getLocalTimezone();
    return _resolver.resolveCurrent(
      latitude: position.latitude,
      longitude: position.longitude,
      deviceTimezoneId: timezone.identifier,
    );
  }

  Future<PrayerLocation> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PrayerLocationException('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const PrayerLocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PrayerLocationException(
        'Location permission is permanently denied.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final timezone = await FlutterTimezone.getLocalTimezone();

    return _resolver.resolveCurrent(
      latitude: position.latitude,
      longitude: position.longitude,
      deviceTimezoneId: timezone.identifier,
    );
  }

  PrayerLocation fromCity(CityOption city) => PrayerLocation(
        latitude: city.latitude,
        longitude: city.longitude,
        city: city.city,
        region: city.region,
        country: city.country,
        countryCode: city.countryCode,
        timezoneId: city.timezoneId,
        source: PrayerLocationSource.city,
      );
}
