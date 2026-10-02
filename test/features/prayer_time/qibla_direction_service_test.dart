import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/domain/qibla_direction_service.dart';

void main() {
  const service = QiblaDirectionService();

  group('QiblaDirectionService.calculateBearing', () {
    test('calculates the expected bearing from Karachi', () {
      final bearing = service.calculateBearing(
        latitude: 24.8607,
        longitude: 67.0011,
      );

      expect(bearing, closeTo(267.741, .01));
    });

    test('calculates the expected bearing from New York', () {
      final bearing = service.calculateBearing(
        latitude: 40.7128,
        longitude: -74.0060,
      );

      expect(bearing, closeTo(58.482, .01));
    });

    test('normalizes bearings into the 0 to 360 degree range', () {
      final bearing = service.calculateBearing(
        latitude: 90,
        longitude: 0,
      );

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });

    test('rejects invalid coordinates', () {
      expect(
        () => service.calculateBearing(latitude: 91, longitude: 0),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.calculateBearing(latitude: 0, longitude: 181),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.calculateBearing(
          latitude: double.nan,
          longitude: 0,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('QiblaDirectionService heading helpers', () {
    test('converts magnetic heading to true heading', () {
      expect(
        service.trueHeadingFromMagnetic(
          magneticHeading: 350,
          declination: 15,
        ),
        closeTo(5, .0001),
      );
    });

    test('calculates the shortest signed qibla rotation', () {
      expect(
        service.relativeQiblaAngle(
          qiblaBearing: 5,
          trueHeading: 355,
        ),
        closeTo(10, .0001),
      );
      expect(
        service.relativeQiblaAngle(
          qiblaBearing: 355,
          trueHeading: 5,
        ),
        closeTo(-10, .0001),
      );
    });
  });
}
