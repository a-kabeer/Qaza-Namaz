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

  Future<void> revealContinue(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Continue'),
      300,
      scrollable: find.byType(Scrollable),
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

    await revealContinue(tester);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Qaza add flow advances to date selection for Gregorian mode', (tester) async {
    await pumpFlow(tester);
    await revealContinue(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3 • Date Selection'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Next: Choose missed prayers'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Next: Choose missed prayers'), findsOneWidget);
  });

  testWidgets('Hijri mode advances into the calendar picker in the Hijri view', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Hijri'));
    await tester.pumpAndSettle();

    await revealContinue(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Task 3G: Hijri is fully supported — the picker renders the Hijri view.
    expect(find.text('Hijri calendar (Umm al-Qura)'), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
  });
}
