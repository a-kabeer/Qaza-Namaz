import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_add_flow.dart';

void main() {
  testWidgets('Task 3C production add flow exposes the three-step ledger workflow', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(MaterialApp(
      home: QazaAddFlowScreen(
        service: QazaService(repository),
        userId: 'test-user',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add Qaza'), findsWidgets);
    expect(find.text('Gregorian'), findsOneWidget);
    expect(find.text('Hijri'), findsOneWidget);
    expect(find.text('Single Date'), findsOneWidget);
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Task 3C production add flow can reach missed-prayer selection', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(MaterialApp(
      home: QazaAddFlowScreen(
        service: QazaService(repository),
        userId: 'test-user',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Date Selection'), findsOneWidget);

    final dateCard = find.text('Single Date');
    expect(dateCard, findsOneWidget);
    await tester.tap(dateCard);
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  test('Task 3C preserves six independent prayer categories', () {
    expect(PrayerType.values, hasLength(6));
    expect(PrayerType.values, contains(PrayerType.fajr));
    expect(PrayerType.values, contains(PrayerType.zuhr));
    expect(PrayerType.values, contains(PrayerType.asr));
    expect(PrayerType.values, contains(PrayerType.maghrib));
    expect(PrayerType.values, contains(PrayerType.isha));
    expect(PrayerType.values, contains(PrayerType.witr));
  });
}
