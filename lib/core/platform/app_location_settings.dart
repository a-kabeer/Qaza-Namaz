import 'package:flutter/services.dart';

enum AppLocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
}

class AppLocationPosition {
  const AppLocationPosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// Small platform abstraction for device GPS without any third-party
/// location SDK.
class AppLocationSettings {
  const AppLocationSettings();

  static const MethodChannel _channel =
      MethodChannel('qaza_namaz/location');

  Future<bool> isLocationServiceEnabled() async =>
      await _channel.invokeMethod<bool>('isLocationServiceEnabled') ?? false;

  Future<AppLocationPermission> checkPermission() async {
    final value = await _channel.invokeMethod<String>('checkPermission');
    return _parsePermission(value);
  }

  Future<AppLocationPermission> requestPermission() async {
    final value = await _channel.invokeMethod<String>('requestPermission');
    return _parsePermission(value);
  }

  Future<bool> ensureLocationServicesEnabled() async {
    if (await isLocationServiceEnabled()) return true;
    return await _channel.invokeMethod<bool>('ensureLocationServices') ?? false;
  }

  Future<AppLocationPosition> getCurrentPosition() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');

    if (result == null) {
      throw StateError('The device did not return a current location.');
    }

    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw StateError('The device returned an invalid location.');
    }

    return AppLocationPosition(latitude: latitude, longitude: longitude);
  }

  Future<bool> openAppSettings() async =>
      await _channel.invokeMethod<bool>('openAppSettings') ?? false;

  static AppLocationPermission _parsePermission(String? value) {
    return switch (value) {
      'whileInUse' => AppLocationPermission.whileInUse,
      'always' => AppLocationPermission.always,
      'deniedForever' => AppLocationPermission.deniedForever,
      _ => AppLocationPermission.denied,
    };
  }
}
