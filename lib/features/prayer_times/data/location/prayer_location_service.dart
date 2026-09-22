import 'package:geolocator/geolocator.dart';
import 'package:timezone_country/timezone_country.dart';

import '../../domain/prayer_times_models.dart';
import '../offline_location_data_source.dart';

abstract class PrayerLocationService {
  Future<PrayerLocation> getCurrentLocation({String? locale});
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

enum PrayerLocationErrorKind {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  positionUnavailable,
  invalidPosition,
}

class PrayerLocationException implements Exception {
  const PrayerLocationException(
    this.kind,
    this.message,
  );

  final PrayerLocationErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

class GeolocatorPrayerLocationService implements PrayerLocationService {
  const GeolocatorPrayerLocationService({
    required OfflineLocationDataSource dataSource,
  }) : _dataSource = dataSource;

  final OfflineLocationDataSource _dataSource;

  @override
  Future<PrayerLocation> getCurrentLocation({String? locale}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PrayerLocationException(
        PrayerLocationErrorKind.serviceDisabled,
        'Location services are turned off.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const PrayerLocationException(
        PrayerLocationErrorKind.permissionDenied,
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PrayerLocationException(
        PrayerLocationErrorKind.permissionPermanentlyDenied,
        'Location permission is permanently denied.',
      );
    }

    final accuracyStatus = await Geolocator.getLocationAccuracy();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
      timeLimit: const Duration(seconds: 12),
    );

    _validatePosition(position);

    final nearestCity = await _dataSource.findNearestCity(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final countryCode = nearestCity?.countryCode;
    final timezone = nearestCity?.timezone ??
        TimezoneConvert.nearestTimezone(
          position.latitude,
          position.longitude,
          countryCode: countryCode,
        );

    final accuracyKind = switch (accuracyStatus) {
      LocationAccuracyStatus.reduced => LocationAccuracyKind.approximate,
      LocationAccuracyStatus.precise => LocationAccuracyKind.precise,
      LocationAccuracyStatus.unknown => position.accuracy >= 1000
          ? LocationAccuracyKind.approximate
          : LocationAccuracyKind.precise,
    };

    return PrayerLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      country: nearestCity?.country,
      city: nearestCity?.name,
      region: nearestCity?.region,
      countryCode: nearestCity?.countryCode,
      timezone: timezone,
      source: LocationSource.device,
      accuracyMeters:
          position.accuracy.isFinite ? position.accuracy : null,
      accuracyKind: accuracyKind,
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  void _validatePosition(Position position) {
    final validCoordinates = position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
    final validAccuracy =
        position.accuracy.isFinite && position.accuracy >= 0;

    if (!validCoordinates || !validAccuracy || position.accuracy > 100000) {
      throw const PrayerLocationException(
        PrayerLocationErrorKind.invalidPosition,
        'The device returned an unusable location.',
      );
    }
  }
}
