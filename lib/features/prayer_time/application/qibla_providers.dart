import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geomag/geomag.dart';

import '../data/device_compass_service.dart';
import '../domain/qibla_direction_service.dart';
import 'prayer_time_providers.dart';

final qiblaDirectionServiceProvider = Provider<QiblaDirectionService>(
  (ref) => const QiblaDirectionService(),
);

final magneticDeclinationServiceProvider = Provider<MagneticDeclinationService>(
  (ref) => MagneticDeclinationService(),
);

final qiblaBearingProvider = Provider<double?>((ref) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final location = snapshot?.location;
  if (location == null) return null;

  try {
    return ref.read(qiblaDirectionServiceProvider).calculateBearing(
          latitude: location.latitude,
          longitude: location.longitude,
        );
  } on FormatException {
    return null;
  }
});

final magneticDeclinationProvider = Provider<double?>((ref) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final location = snapshot?.location;
  if (location == null) return null;

  try {
    return ref.read(magneticDeclinationServiceProvider).calculate(
          latitude: location.latitude,
          longitude: location.longitude,
          date: DateTime.now().toUtc(),
        );
  } on FormatException {
    return null;
  }
});

final compassServiceProvider = Provider<CompassService>(
  (ref) => const DeviceCompassService(),
);

final compassSensorAvailableProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.read(compassServiceProvider).hasSensors();
});

final compassReadingProvider =
    StreamProvider.autoDispose<CompassReading>((ref) {
  return ref.read(compassServiceProvider).readings();
});

class MagneticDeclinationService {
  MagneticDeclinationService({GeoMag? model}) : _model = model ?? GeoMag();

  final GeoMag _model;

  double calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid latitude or longitude.');
    }

    if (date.isUtc == false) {
      return _model.calculate(
        latitude,
        longitude,
        0,
        date.toUtc(),
      ).dec;
    }

    return _model.calculate(
      latitude,
      longitude,
      0,
      date,
    ).dec;
  }
}
