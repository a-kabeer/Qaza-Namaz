import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';

void main() {
  test(
      'calendarDayDifference counts Gregorian dates without elapsed-hour assumptions',
      () {
    final start = DateTime(2024, 3, 10, 0, 30);
    final end = DateTime(2024, 3, 11, 0, 15);
    expect(LocalDateService.calendarDayDifference(start, end), 1);
  });

  test('addCalendarDays preserves Gregorian calendar dates', () {
    final start = DateTime(2024, 3, 10, 23, 30);
    expect(LocalDateService.addCalendarDays(start, 1), DateTime(2024, 3, 11));
    expect(LocalDateService.addCalendarDays(start, -1), DateTime(2024, 3, 9));
  });

  test('compareCalendarDates ignores time of day', () {
    expect(
      LocalDateService.compareCalendarDates(
        DateTime(2026, 9, 30, 23, 59),
        DateTime(2026, 9, 30, 0, 1),
      ),
      0,
    );
  });
}
