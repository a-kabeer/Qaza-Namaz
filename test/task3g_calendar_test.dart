import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';

import 'support/in_memory_qaza_repository.dart';

Widget _scope(Widget child, InMemoryQazaRepository repository) {
  return ProviderScope(
    overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
    ],
    child: child,
  );
}

Future<void> _scrollToContinue(WidgetTester tester) async {
  final finder = find.byKey(const Key('qaza_continue_button'));
  await tester.scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _scrollToNextPrayers(WidgetTester tester) async {
  final finder = find.text('Next: Choose missed prayers');
  await tester.scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _scrollToReview(WidgetTester tester) async {
  final finder = find.text('Review & Create Records');
  await tester.scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _scrollToPrayer(WidgetTester tester, String prayer) async {
  final finder = find.text(prayer, skipOffstage: false);
  await tester.scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first, duration: const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Gregorian calendar renders and navigates months', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: AddQazaScreen()), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single'));
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
  });

  testWidgets('Gregorian calendar displays Hijri as secondary information', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: AddQazaScreen()), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single'));
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
  });

  testWidgets('calendar stores canonical Gregorian originalDate through Qaza flow', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: AddQazaScreen()), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single'));
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-13')));
    await tester.pumpAndSettle();
    await _scrollToNextPrayers(tester);
    await tester.tap(find.text('Next: Choose missed prayers'));
    await tester.pumpAndSettle();
    await _scrollToPrayer(tester, 'Maghrib');
    await tester.tap(find.text('Maghrib', skipOffstage: false));
    await tester.pumpAndSettle();
    await _scrollToReview(tester);
    await tester.tap(find.text('Review & Create Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(1));
    final storedDate = records.single.originalDate;
    expect([storedDate.year, storedDate.month, storedDate.day], [2026, 9, 13]);
    expect(records.single.prayerType, PrayerType.maghrib);
  });

  testWidgets('range flow persists every day in the selected range', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: AddQazaScreen()), repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Range'));
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-13')));
    await tester.pumpAndSettle();
    await _scrollToNextPrayers(tester);
    await tester.tap(find.text('Next: Choose missed prayers'));
    await tester.pumpAndSettle();
    await _scrollToPrayer(tester, 'Fajr');
    await tester.tap(find.text('Fajr', skipOffstage: false).first);
    await tester.pumpAndSettle();
    await _scrollToReview(tester);
    await tester.tap(find.text('Review & Create Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(4));
    expect(records.map((r) => r.originalDate).toSet(), {DateTime(2026, 9, 10), DateTime(2026, 9, 11), DateTime(2026, 9, 12), DateTime(2026, 9, 13)});
  });
}
