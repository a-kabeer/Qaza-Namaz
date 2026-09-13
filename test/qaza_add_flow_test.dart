import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_add_flow_v2.dart';

void main() {
  Future<void> pumpFlow(WidgetTester tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: QazaAddFlowV2Screen(
          userId: 'test-user',
          service: QazaService(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Qaza add flow starts with method and selection choices', (tester) async {
    await pumpFlow(tester);
    expect(find.text('Add Qaza'), findsWidgets);
    expect(find.text('Gregorian'), findsOneWidget);
    expect(find.text('Hijri'), findsOneWidget);
    expect(find.text('Single Date'), findsOneWidget);
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('Qaza add flow advances to date selection for Gregorian mode', (tester) async {
    await pumpFlow(tester);
    final continueButton = find.byType(FilledButton);
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3 • Date Selection'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);
    expect(find.text('Next: Choose missed prayers'), findsOneWidget);
  });

  testWidgets('Hijri selection stays explicitly gated to the calendar engine task', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Hijri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Hijri calendar selection is reserved for the calendar engine task.'),
      findsOneWidget,
    );
    expect(find.text('Step 1 of 3 • Range Setup'), findsOneWidget);
  });
}
