import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Reusable platform bridge for location setup.
class AppLocationSettings {
  const AppLocationSettings();

  Future<bool> ensureLocationServicesEnabled() async {
    if (await Geolocator.isLocationServiceEnabled()) return true;

    if (!Platform.isAndroid) {
      return Geolocator.openLocationSettings();
    }

    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
