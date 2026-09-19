import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_namaz/features/calculator/calculator_persistence.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and restores calculator state', () async {
    final prefs = await SharedPreferences.getInstance();
    const persistence = CalculatorPersistence();
    final snapshot = CalculatorSnapshot(
      step: 2,
      dob: DateTime(1990, 3, 4),
      balighMode: 'age',
      balighAge: 12,
      balighDate: null,
      prayerStartMode: 'exactDate',
      prayerStartAge: 18,
      prayerStartDate: DateTime(2020, 5, 6),
      includeWitr: true,
      hasCalculation: true,
    );

    await persistence.save(snapshot, userId: 'user-a', preferences: prefs);
    final restored =
        await persistence.load(userId: 'user-a', preferences: prefs);

    expect(restored, isNotNull);
    expect(restored!.step, 2);
    expect(restored.dob, DateTime(1990, 3, 4));
    expect(restored.balighMode, 'age');
    expect(restored.balighAge, 12);
    expect(restored.prayerStartMode, 'exactDate');
    expect(restored.prayerStartDate, DateTime(2020, 5, 6));
    expect(restored.includeWitr, isTrue);
    expect(restored.hasCalculation, isTrue);
  });

  test('calculator state is isolated by user id', () async {
    final prefs = await SharedPreferences.getInstance();
    const persistence = CalculatorPersistence();
    final snapshot = CalculatorSnapshot(
      step: 1,
      dob: DateTime(2000, 1, 2),
      balighMode: 'age',
      balighAge: 12,
      balighDate: null,
      prayerStartMode: 'age',
      prayerStartAge: 18,
      prayerStartDate: null,
      includeWitr: false,
      hasCalculation: false,
    );

    await persistence.save(snapshot, userId: 'user-a', preferences: prefs);

    expect(await persistence.load(userId: 'user-a', preferences: prefs),
        isNotNull);
    expect(
        await persistence.load(userId: 'user-b', preferences: prefs), isNull);
  });

  test('missing and malformed stored values fail safely', () async {
    final prefs = await SharedPreferences.getInstance();
    const persistence = CalculatorPersistence();
    expect(
        await persistence.load(userId: 'missing', preferences: prefs), isNull);

    await prefs.setString(
      persistence.keyForUser('bad'),
      '{"schemaVersion":1,"step":"invalid"}',
    );
    expect(await persistence.load(userId: 'bad', preferences: prefs), isNull);
  });
}
