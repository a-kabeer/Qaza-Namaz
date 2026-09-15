import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/qaza/qaza_add_flow_v2.dart';

void main() {
  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com'))),
        ],
        child: const MaterialApp(home: QazaAddFlowV2Screen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToContinue(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byKey(const Key('qaza_continue_button')), 300, scrollable: find.byType(Scrollable).first);
  }

  testWidgets('Qaza add flow exposes Gregorian/Hijri and single/range/multiple choices', (tester) async {
    await pumpFlow(tester);
    expect(find.byKey(const Key('qaza_flow_heading')), findsOneWidget);
    expect(find.text('Gregorian'), findsOneWidget);
    expect(find.text('Hijri'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('Multiple'), findsOneWidget);
  });

  testWidgets('Qaza add flow advances to the package-backed calendar', (tester) async {
    await pumpFlow(tester);
    await scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 • Date Selection'), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
    expect(find.byKey(const Key('calendar_mode_selector')), findsOneWidget);
  });
}
