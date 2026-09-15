// Task 3G regression coverage. This file is intentionally unchanged in scope:
// it verifies the existing calendar engine while Task 3H/architecture work
// consumes it through Riverpod overrides.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/calendar/calendar_engine.dart';
import 'package:qaza_namaz/domain/calendar/calendar_labels.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_add_flow_v2.dart';

final DateTime _now = DateTime(2026, 9, 14);

void main() {
  late InMemoryQazaRepository repository;
  late CalendarEngine engine;
  setUp(() { repository = InMemoryQazaRepository(); engine = CalendarEngine(now: () => _now); });

  Finder dayKey(DateTime day) => find.byKey(Key('calendar_day_${engine.dateKey(day)}'));

  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'u1', email: 'test@example.com'))),
        calendarEngineProvider.overrideWithValue(engine),
      ],
      child: const MaterialApp(home: QazaAddFlowV2Screen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> continueToDates(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Continue'), 300, scrollable: find.byType(Scrollable));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> continueToPrayers(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Next: Choose missed prayers'), 300, scrollable: find.byType(Scrollable));
    await tester.tap(find.text('Next: Choose missed prayers'));
    await tester.pumpAndSettle();
  }

  Future<void> pickPrayersAndSave(WidgetTester tester, List<String> prayerLabels) async {
    for (final label in prayerLabels) { await tester.tap(find.text(label)); await tester.pumpAndSettle(); }
    await tester.scrollUntilVisible(find.text('Review & Create Records'), 300, scrollable: find.byType(Scrollable));
    await tester.tap(find.text('Review & Create Records'));
    await tester.pumpAndSettle();
    expect(find.text('Qaza records created'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('Gregorian single date saves one normalized pending record with the original date preserved', (tester) async {
    await pumpFlow(tester); await continueToDates(tester);
    await tester.tap(dayKey(DateTime(2026, 9, 10))); await tester.pumpAndSettle();
    expect(find.text('10 Sep 2026'), findsOneWidget);
    expect(find.text(CalendarLabels.formatHijriDate(engine.gregorianToHijri(DateTime(2026, 9, 10))), findsOneWidget);
    await continueToPrayers(tester); await pickPrayersAndSave(tester, const ['Fajr']);
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(1));
    expect(records.single.prayerType, PrayerType.fajr);
    expect(records.single.originalDate, DateTime(2026, 9, 10));
    expect(records.single.status, QazaStatus.pending);
  });

  testWidgets('Hijri mode stores the canonical Gregorian date, never a display string', (tester) async {
    await pumpFlow(tester); await tester.tap(find.text('Hijri')); await tester.pumpAndSettle(); await continueToDates(tester);
    expect(find.text('Hijri calendar (Umm al-Qura)'), findsOneWidget);
    expect(find.text("Rabi' Al-Thani 1448 AH"), findsOneWidget);
    await tester.tap(dayKey(DateTime(2026, 9, 13))); await tester.pumpAndSettle();
    expect(find.text("2 Rabi' Al-Thani 1448 AH"), findsOneWidget);
    expect(find.text('13 Sep 2026'), findsOneWidget);
    await continueToPrayers(tester); await pickPrayersAndSave(tester, const ['Maghrib']);
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(1));
    expect(records.single.prayerType, PrayerType.maghrib);
    expect(records.single.originalDate, DateTime(2026, 9, 13));
  });

  testWidgets('range selection expands to one pending record per day with no gaps, no duplicates, and Witr kept separate from Isha', (tester) async {
    await pumpFlow(tester); await tester.tap(find.text('Date Range')); await tester.pumpAndSettle(); await continueToDates(tester);
    await tester.tap(dayKey(DateTime(2026, 9, 10))); await tester.pumpAndSettle();
    expect(find.text('Tap a later date to finish the range'), findsOneWidget);
    await tester.tap(dayKey(DateTime(2026, 9, 13))); await tester.pumpAndSettle();
    expect(find.text('13 Sep 2026'), findsOneWidget);
    await continueToPrayers(tester);
    expect(find.textContaining('4 days'), findsOneWidget);
    await pickPrayersAndSave(tester, const ['Isha', 'Witr']);
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(8));
    final expectedDays = [10, 11, 12, 13].map((d) => DateTime(2026, 9, d)).toSet();
    for (final type in [PrayerType.isha, PrayerType.witr]) {
      final forType = records.where((r) => r.prayerType == type).toList();
      expect(forType, hasLength(4));
      expect(forType.map((r) => r.originalDate).toSet(), expectedDays);
      expect(forType.every((r) => r.status == QazaStatus.pending), isTrue);
    }
    final combos = records.map((r) => '${r.prayerType.name}_${engine.dateKey(r.originalDate)}').toSet();
    expect(combos, hasLength(8));
  });

  testWidgets('future dates are blocked inside the flow and save stays off', (tester) async {
    await pumpFlow(tester); await continueToDates(tester);
    final tomorrow = dayKey(DateTime(2026, 9, 15));
    expect(tomorrow, findsOneWidget);
    expect(find.descendant(of: tomorrow, matching: find.byType(InkWell)), findsNothing);
    await tester.tap(tomorrow, warnIfMissed: false); await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_selection_prompt')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next: Choose missed prayers'), 200, scrollable: find.byType(Scrollable));
    final nextButton = tester.widget<FilledButton>(find.ancestor(of: find.text('Next: Choose missed prayers'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(nextButton.onPressed, isNull);
    expect(await repository.getRecords(userId: 'u1'), isEmpty);
  });
}
