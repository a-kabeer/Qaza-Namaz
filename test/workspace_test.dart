import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'support/in_memory_qaza_repository.dart';

Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  Future<void> pumpWorkspace(WidgetTester tester, InMemoryQazaRepository repository) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [qazaRepositoryProvider.overrideWithValue(repository), authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com')))],
      child: const MaterialApp(home: WorkspaceShell()),
    ));
    await _pumpNavigation(tester);
  }
  Future<void> revealPrayerLedger(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -500));
    await _pumpNavigation(tester);
  }
  testWidgets('Workspace exposes four primary navigation destinations', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
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
      QazaRecord(id: 'test_fajr_2026-09-01', userId: 'test-user', prayerType: PrayerType.fajr, originalDate: DateTime(2026, 9, 1), createdAt: now, updatedAt: now),
      QazaRecord(id: 'test_zuhr_2026-09-02', userId: 'test-user', prayerType: PrayerType.zuhr, originalDate: DateTime(2026, 9, 2), status: QazaStatus.completed, completedAt: now, createdAt: now, updatedAt: now),
    ]);
    await pumpWorkspace(tester, repository);
    expect(find.text('1 pending'), findsWidgets);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('50% completed'), findsOneWidget);
  });
  testWidgets('Selecting Calculator, Logs and Settings preserves destination state', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Calculator').first);
    await _pumpNavigation(tester);
    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Logs').first);
    await _pumpNavigation(tester);
    expect(find.text('Logs & Progress'), findsOneWidget);
    expect(find.text('No completed Qaza yet.'), findsOneWidget);
    await tester.tap(find.text('Settings').first);
    await _pumpNavigation(tester);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Prayer & Fiqh Rules'), findsOneWidget);
  });
}
