import 'package:flutter_timezone/flutter_timezone.dart';

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
    if (!await _locationSettings.isLocationServiceEnabled()) {
      return PrayerLocationRequirement.locationServiceDisabled;
    }

    return switch (await _locationSettings.checkPermission()) {
      AppLocationPermission.denied =>
        PrayerLocationRequirement.permissionRequired,
      AppLocationPermission.deniedForever =>
        PrayerLocationRequirement.permissionDeniedForever,
      AppLocationPermission.whileInUse || AppLocationPermission.always =>
        PrayerLocationRequirement.ready,
    };
  }

  Future<bool> openAppSettings() => _locationSettings.openAppSettings();

  /// Performs a single explicit GPS acquisition. No other code path should
  /// call this method automatically.
  Future<PrayerLocation> getCurrent() async {
    if (!await _locationSettings.isLocationServiceEnabled()) {
      final enabled = await _locationSettings.ensureLocationServicesEnabled();
      if (!enabled || !await _locationSettings.isLocationServiceEnabled()) {
        throw const PrayerLocationSetupException(
          PrayerLocationSetupFailure.locationServiceResolutionCancelled,
        );
      }
    }

    var permission = await _locationSettings.checkPermission();
    if (permission == AppLocationPermission.denied) {
      permission = await _locationSettings.requestPermission();
    }

    if (permission == AppLocationPermission.denied) {
      throw const PrayerLocationSetupException(
        PrayerLocationSetupFailure.permissionDenied,
      );
    }
    if (permission == AppLocationPermission.deniedForever) {
      throw const PrayerLocationSetupException(
        PrayerLocationSetupFailure.permissionDeniedForever,
      );
    }

    final position = await _locationSettings.getCurrentPosition();
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
