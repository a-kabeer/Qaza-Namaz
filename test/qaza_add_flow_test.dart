import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          activeUserIdProvider.overrideWithValue('test-user'),
        ],
        child: const MaterialApp(home: AddQazaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('Step 1 combines date mode and calendar', (tester) async {
    await pumpFlow(tester);

    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.byKey(const Key('qaza_flow_heading')), findsOneWidget);
    expect(find.text('Date selection'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('Multiple'), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
    expect(find.byKey(const Key('calendar_month_header')), findsOneWidget);
    expect(find.byKey(const Key('calendar_hijri_month_label')), findsOneWidget);
    expect(find.text('Step 2 of 3 • Date Selection'), findsNothing);
  });

  testWidgets('changing date mode keeps the flow on Step 1 and resets date selection', (tester) async {
    await pumpFlow(tester);

    await scrollToKey(tester, const Key('calendar_day_2026-09-15'));
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-15')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Range'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.text('Selected dates'), findsNothing);

    await tester.tap(find.text('Multiple'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
  });

  testWidgets('selected date advances to Step 2 and Step 3 preserves selections', (tester) async {
    await pumpFlow(tester);

    await scrollToKey(tester, const Key('calendar_day_2026-09-15'));
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-15')));
    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('qaza_continue_button'));
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);
    expect(find.text('Select Missed Prayers'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Zuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(find.text('Witr'), findsOneWidget);

    await tester.tap(find.text('Fajr').first);
    await tester.pumpAndSettle();
    await scrollToKey(tester, const Key('qaza_prayers_continue_button'));
    await tester.tap(find.byKey(const Key('qaza_prayers_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3 • Review & Add'), findsOneWidget);
    expect(find.text('Review & Add'), findsOneWidget);
    expect(find.text('Selected dates'), findsOneWidget);
    expect(find.text('Selected date: 15/09/2026'), findsOneWidget);
    expect(find.text('Fajr'), findsWidgets);
    expect(find.byKey(const Key('qaza_final_add_button')), findsOneWidget);
  });

  testWidgets('back navigation preserves selected date and prayer state', (tester) async {
    await pumpFlow(tester);

    await scrollToKey(tester, const Key('calendar_day_2026-09-15'));
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-15')));
    await tester.pumpAndSettle();
    await scrollToKey(tester, const Key('qaza_continue_button'));
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fajr').first);
    await tester.pumpAndSettle();
    await scrollToKey(tester, const Key('qaza_prayers_continue_button'));
    await tester.tap(find.byKey(const Key('qaza_prayers_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3 • Review & Add'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);
    final fajr = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Fajr').first,
        matching: find.byType(CheckboxListTile),
      ).first,
    );
    expect(fajr.value, isTrue);
  });
}
