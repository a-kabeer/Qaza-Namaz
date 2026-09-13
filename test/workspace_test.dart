import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/ui/workspace_v2.dart';

void main() {
  Future<void> pumpWorkspace(WidgetTester tester, InMemoryQazaRepository repository) async {
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
    await tester.scrollUntilVisible(
      find.text('Prayer ledger'),
      400,
      scrollable: find.byType(Scrollable),
    );
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
    final emptyHistory = find.text('No completed Qaza yet.', skipOffstage: false);
    expect(emptyHistory, findsOneWidget);
    await tester.scrollUntilVisible(emptyHistory, 300, scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    final fiqh = find.text('Prayer & Fiqh Rules', skipOffstage: false);
    expect(fiqh, findsOneWidget);
    await tester.scrollUntilVisible(fiqh, 300, scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
  });
}
