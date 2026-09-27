import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Reusable platform bridge for location setup.
///
/// Android uses the native Google Play Services settings-resolution flow so
/// users get the system Location Services prompt rather than an in-app
/// imitation. Other platforms fall back to the platform location-settings
/// page because this application currently targets Android.
class AppLocationSettings {
  const AppLocationSettings();

  static const MethodChannel _channel =
      MethodChannel('qaza_namaz/location_settings');

  Future<bool> ensureLocationServicesEnabled() async {
    if (await Geolocator.isLocationServiceEnabled()) return true;

    if (!Platform.isAndroid) {
      return Geolocator.openLocationSettings();
    }

    try {
      return await _channel.invokeMethod<bool>(
            'ensureLocationServices',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
