import 'dart:math' as math;

/// Calculates the initial great-circle bearing from a saved location to the
/// Kaaba. The result is a geographic bearing measured clockwise from true
/// north and is intentionally pure/local so it works offline.
class QiblaDirectionService {
  const QiblaDirectionService();

  static const double kaabaLatitude = 21.422511;
  static const double kaabaLongitude = 39.82615;

  double calculateBearing({
    required double latitude,
    required double longitude,
  }) {
    _validateCoordinate(latitude, longitude);

    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(kaabaLatitude);
    final deltaLongitude = _toRadians(kaabaLongitude - longitude);

    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);

    return _normalizeDegrees(_toDegrees(math.atan2(y, x)));
  }

  static void _validateCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid latitude or longitude.');
    }
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  static double _toDegrees(double radians) => radians * 180 / math.pi;

  static double _normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}
