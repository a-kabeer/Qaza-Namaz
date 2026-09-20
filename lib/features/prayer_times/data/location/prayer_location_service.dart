import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/prayer_times_models.dart';

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
  GeolocatorPrayerLocationService({
    Geocoding? geocoding,
  }) : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

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

    final accuracyKind = switch (accuracyStatus) {
      LocationAccuracyStatus.reduced => LocationAccuracyKind.approximate,
      LocationAccuracyStatus.precise => LocationAccuracyKind.precise,
      LocationAccuracyStatus.unknown => LocationAccuracyKind.unknown,
    };

    String? country;
    String? city;
    String? region;
    String? countryCode;

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        country = _clean(placemark.country);
        city = _clean(placemark.locality) ??
            _clean(placemark.subAdministrativeArea) ??
            _clean(placemark.administrativeArea);
        region = _clean(placemark.administrativeArea);
        countryCode = _clean(placemark.isoCountryCode);
      }
    } catch (_) {
      // Reverse geocoding is metadata only. Coordinates remain usable.
    }

    return PrayerLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      country: country,
      city: city,
      region: region,
      countryCode: countryCode,
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

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
