import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

void main() {
  testWidgets('calendar uses theme tokens for selection surfaces',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2027, 3, 15))
        ],
        child: TestApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: CalendarPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_hijri_month_label')), findsOneWidget);
    expect(find.byKey(const Key('calendar_selection_prompt')), findsOneWidget);
  });

  testWidgets('calendar remains readable with dark theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2027, 3, 15))
        ],
        child: TestApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: CalendarPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-15')));
    await tester.pumpAndSettle();

    final summary =
        tester.widget<Card>(find.byKey(const Key('calendar_selected_summary')));
    expect(summary.color, isNull);
    expect(find.byKey(const Key('calendar_clear_selection')), findsOneWidget);
  });
}
