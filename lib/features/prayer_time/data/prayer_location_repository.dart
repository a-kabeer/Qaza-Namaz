import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/platform/app_location_settings.dart';
import '../domain/prayer_location.dart';
import 'offline_city_resolver.dart';

class PrayerLocationRepository {
  const PrayerLocationRepository(
    this._resolver, {
    AppLocationSettings locationSettings = const AppLocationSettings(),
  }) : _locationSettings = locationSettings;

  final OfflineCityResolver _resolver;
  final AppLocationSettings _locationSettings;

  Future<PrayerLocationRequirement> currentLocationRequirement() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PrayerLocationRequirement.locationServiceDisabled;
    }

    return switch (await Geolocator.checkPermission()) {
      LocationPermission.denied => PrayerLocationRequirement.permissionRequired,
      LocationPermission.deniedForever =>
        PrayerLocationRequirement.permissionDeniedForever,
      LocationPermission.whileInUse ||
      LocationPermission.always =>
        PrayerLocationRequirement.ready,
      LocationPermission.unableToDetermine =>
        PrayerLocationRequirement.permissionRequired,
    };
  }

  Future<bool> openAppSettings() => _locationSettings.openAppSettings();

  /// Performs a single explicit GPS acquisition. No other code path should
  /// call this method automatically.
  Future<PrayerLocation> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      final enabled = await _locationSettings.ensureLocationServicesEnabled();
      if (!enabled || !await Geolocator.isLocationServiceEnabled()) {
        throw const PrayerLocationSetupException(
          PrayerLocationSetupFailure.locationServiceResolutionCancelled,
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const PrayerLocationSetupException(
        PrayerLocationSetupFailure.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PrayerLocationSetupException(
        PrayerLocationSetupFailure.permissionDeniedForever,
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
        geonameId: city.geonameId,
      );
}
