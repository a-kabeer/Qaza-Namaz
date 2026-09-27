import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/utils/date_formatters.dart';

void main() {
  group('DateFormatters.formatDurationHhMmSs', () {
    test('zero-pads hours, minutes, and seconds', () {
      expect(
        DateFormatters.formatDurationHhMmSs(
          const Duration(hours: 1, minutes: 8, seconds: 7),
        ),
        '01:08:07',
      );
    });

    test('formats durations under one hour with zero-padded hours', () {
      expect(
        DateFormatters.formatDurationHhMmSs(
          const Duration(minutes: 4, seconds: 32),
        ),
        '00:04:32',
      );
    });

    test('clamps negative durations to zero', () {
      expect(
        DateFormatters.formatDurationHhMmSs(
          const Duration(seconds: -1),
        ),
        '00:00:00',
      );
    });
  });
}
