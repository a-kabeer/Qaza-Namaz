import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/ui/workspace_v2.dart';

void main() {
  Future<void> pumpWorkspace(WidgetTester tester, InMemoryQazaRepository repository) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceShellV2(
          userId: 'test-user',
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> revealPrayerLedger(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
  }

  testWidgets('Workspace exposes four primary navigation destinations', (tester) async {
    final repository = InMemoryQazaRepository();
    await pumpWorkspace(tester, repository);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Add Qaza'), findsOneWidget);

    await revealPrayerLedger(tester);
    expect(find.text('Prayer ledger'), findsOneWidget);
  });

  testWidgets('Dashboard derives live totals from individual records', (tester) async {
    final repository = InMemoryQazaRepository();
    final now = DateTime(2026, 9, 13);

    await repository.addRecords([
      QazaRecord(
        id: 'test_fajr_2026-09-01',
        userId: 'test-user',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 1),
        createdAt: now,
        updatedAt: now,
      ),
      QazaRecord(
        id: 'test_zuhr_2026-09-02',
        userId: 'test-user',
        prayerType: PrayerType.zuhr,
        originalDate: DateTime(2026, 9, 2),
        status: QazaStatus.completed,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await pumpWorkspace(tester, repository);

    expect(find.text('1 pending'), findsWidgets);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('50% completed'), findsOneWidget);
  });

  testWidgets('Selecting Calculator, Logs and Settings preserves destination state', (tester) async {
    final repository = InMemoryQazaRepository();
    await pumpWorkspace(tester, repository);

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();
    expect(find.text('Qaza estimate calculator'), findsOneWidget);

    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();
    expect(find.text('Logs & Progress'), findsOneWidget);
    expect(find.text('No completed Qaza yet.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Prayer & Fiqh Rules'), findsOneWidget);
  });
}
