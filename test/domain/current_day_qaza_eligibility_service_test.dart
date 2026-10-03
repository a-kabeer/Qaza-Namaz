import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/services/current_day_qaza_eligibility_service.dart';

CurrentDayQazaPrayerTimeContext _context({
  required DateTime now,
  bool hasSchedule = true,
}) {
  return CurrentDayQazaPrayerTimeContext(
    localNow: now,
    localToday: DateTime(2026, 10, 3),
    cutoffByPrayer: const {
      PrayerType.fajr: DateTime(2026, 10, 3, 6),
      PrayerType.zuhr: DateTime(2026, 10, 3, 15, 30),
      PrayerType.asr: DateTime(2026, 10, 3, 18),
      PrayerType.maghrib: DateTime(2026, 10, 3, 19, 30),
      PrayerType.isha: DateTime(2026, 10, 4, 5),
      PrayerType.witr: DateTime(2026, 10, 4, 5),
    },
    hasSchedule: hasSchedule,
  );
}

void main() {
  const service = CurrentDayQazaEligibilityService();

  test('Fajr is blocked before sunrise and eligible at sunrise', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.fajr,
        context: _context(now: DateTime(2026, 10, 3, 5, 59)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.fajr,
        context: _context(now: DateTime(2026, 10, 3, 6)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('Zuhr becomes eligible at Asr start', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.zuhr,
        context: _context(now: DateTime(2026, 10, 3, 15, 29)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.zuhr,
        context: _context(now: DateTime(2026, 10, 3, 15, 30)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('Asr becomes eligible at Maghrib start', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.asr,
        context: _context(now: DateTime(2026, 10, 3, 17, 59)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.asr,
        context: _context(now: DateTime(2026, 10, 3, 18)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('Maghrib becomes eligible at Isha start', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.maghrib,
        context: _context(now: DateTime(2026, 10, 3, 19, 29)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.maghrib,
        context: _context(now: DateTime(2026, 10, 3, 19, 30)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('Isha and Witr use the next Fajr boundary', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.isha,
        context: _context(now: DateTime(2026, 10, 4, 4, 59)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.witr,
        context: _context(now: DateTime(2026, 10, 4, 4, 59)),
      ),
      CurrentDayQazaTimeEligibility.notYetDue,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.isha,
        context: _context(now: DateTime(2026, 10, 4, 5)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.witr,
        context: _context(now: DateTime(2026, 10, 4, 5)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('historical dates are unaffected', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 2),
        prayerType: PrayerType.fajr,
        context: _context(now: DateTime(2026, 10, 3, 5)),
      ),
      CurrentDayQazaTimeEligibility.eligible,
    );
  });

  test('missing prayer-time schedule never claims today is eligible', () {
    expect(
      service.evaluate(
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.fajr,
        context: _context(
          now: DateTime(2026, 10, 3, 12),
          hasSchedule: false,
        ),
      ),
      CurrentDayQazaTimeEligibility.timeDataUnavailable,
    );
  });
}
