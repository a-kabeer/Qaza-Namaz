import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  Future<void> pumpFlow(WidgetTester tester) async {
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

  Future<void> scrollToContinue(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('qaza_continue_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('Qaza add flow exposes one Gregorian calendar with secondary Hijri and three selection modes', (tester) async {
    await pumpFlow(tester);
    expect(find.byKey(const Key('qaza_flow_heading')), findsOneWidget);
    expect(find.text('Date selection'), findsOneWidget);
    expect(find.text('Gregorian'), findsNothing);
    expect(find.text('Hijri'), findsNothing);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('Multiple'), findsOneWidget);
  });

  testWidgets('Qaza add flow advances to the unified Gregorian calendar', (tester) async {
    await pumpFlow(tester);
    await scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 • Date Selection'), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
    expect(find.byKey(const Key('calendar_month_header')), findsOneWidget);
    expect(find.byKey(const Key('calendar_hijri_month_label')), findsOneWidget);
    expect(find.byKey(const Key('calendar_mode_selector')), findsNothing);
  });
}
