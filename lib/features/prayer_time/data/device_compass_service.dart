import 'dart:math' as math;

import 'package:flutter_device_compass/flutter_device_compass.dart';

class CompassReading {
  const CompassReading({
    required this.heading,
    this.accuracy,
  });

  final double? heading;
  final double? accuracy;
}

abstract interface class CompassService {
  Future<bool> hasSensors();

  Stream<CompassReading> readings();
}

class DeviceCompassService implements CompassService {
  const DeviceCompassService();

  @override
  Future<bool> hasSensors() async => await FlutterCompass.hasSensors == true;

  @override
  Stream<CompassReading> readings() {
    final source =
        FlutterCompass.eventsFor(CompassUpdateOptions.balanced) ??
        const Stream<CompassEvent>.empty();

    return source
        .map(
          (event) => CompassReading(
            heading: _normalizeHeading(event.heading),
            accuracy: _normalizeAccuracy(event.accuracy),
          ),
        )
        .distinct(_sameReading);
  }

  static double? _normalizeHeading(double? heading) {
    if (heading == null || !heading.isFinite) return null;
    final normalized = heading % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double? _normalizeAccuracy(double? accuracy) {
    if (accuracy == null || !accuracy.isFinite || accuracy < 0) return null;
    return accuracy;
  }

  static bool _sameReading(CompassReading previous, CompassReading next) {
    final previousHeading = previous.heading;
    final nextHeading = next.heading;

    if (previousHeading == null || nextHeading == null) {
      return previousHeading == nextHeading &&
          previous.accuracy == next.accuracy;
    }

    final headingDelta = (previousHeading - nextHeading).abs() % 360;
    final circularDelta = math.min(headingDelta, 360 - headingDelta);

    final accuracyEqual =
        (previous.accuracy == null && next.accuracy == null) ||
        (previous.accuracy != null &&
            next.accuracy != null &&
            (previous.accuracy! - next.accuracy!).abs() < .5);

    return circularDelta < .5 && accuracyEqual;
  }
}
