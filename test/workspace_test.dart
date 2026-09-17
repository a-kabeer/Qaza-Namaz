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

  testWidgets('Workspace exposes four primary navigation destinations', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Start Your Qaza Journey'), findsOneWidget);
    expect(find.text('Calculate Qaza'), findsOneWidget);
    expect(find.text('Add Qaza Manually'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
  });

  testWidgets('Home empty state uses the Home state model and opens setup journeys', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());

    expect(find.text('Start Your Qaza Journey'), findsOneWidget);
    expect(find.textContaining('Your Qaza ledger is empty.'), findsOneWidget);
    expect(find.text('Ledger overview'), findsNothing);
    expect(find.text('Prayer ledger'), findsNothing);

    await tester.tap(find.text('Calculate Qaza'));
    await _pumpNavigation(tester);
    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(find.text('Start Your Qaza Journey'), findsOneWidget);

    await tester.tap(find.text('Add Qaza Manually'));
    await _pumpNavigation(tester);
    expect(find.byKey(const Key('qaza_flow_heading')), findsOneWidget);
  });

  testWidgets('Home pending state prioritizes completion and removes dashboard clutter', (tester) async {
    final repository = InMemoryQazaRepository();
    final now = DateTime(2026, 9, 13);
    await repository.addRecords([
      QazaRecord(id: 'pending_fajr', userId: 'test-user', prayerType: PrayerType.fajr, originalDate: DateTime(2026, 9, 1), createdAt: now, updatedAt: now),
      QazaRecord(id: 'pending_zuhr', userId: 'test-user', prayerType: PrayerType.zuhr, originalDate: DateTime(2026, 9, 2), createdAt: now, updatedAt: now),
      QazaRecord(id: 'completed_asr', userId: 'test-user', prayerType: PrayerType.asr, originalDate: DateTime(2026, 9, 3), status: QazaStatus.completed, completedAt: now, createdAt: now, updatedAt: now),
    ]);

    await pumpWorkspace(tester, repository);

    expect(find.text('Keep going'), findsOneWidget);
    expect(find.text('2 Qaza prayers remain in your ledger.'), findsOneWidget);
    expect(find.text('Complete Qaza'), findsOneWidget);
    expect(find.text('Add New Qaza'), findsOneWidget);
    expect(find.text('Continue by prayer'), findsOneWidget);
    expect(find.textContaining('1 pending'), findsNWidgets(2));
    expect(find.text('Ledger overview'), findsNothing);
    expect(find.text('50% completed'), findsNothing);
  });

  testWidgets('Home all-completed state focuses on the next setup action', (tester) async {
    final repository = InMemoryQazaRepository();
    final now = DateTime(2026, 9, 13);
    await repository.addRecords([
      QazaRecord(id: 'completed_fajr', userId: 'test-user', prayerType: PrayerType.fajr, originalDate: DateTime(2026, 9, 1), status: QazaStatus.completed, completedAt: now, createdAt: now, updatedAt: now),
      QazaRecord(id: 'completed_isha', userId: 'test-user', prayerType: PrayerType.isha, originalDate: DateTime(2026, 9, 2), status: QazaStatus.completed, completedAt: now, createdAt: now, updatedAt: now),
    ]);

    await pumpWorkspace(tester, repository);

    expect(find.text('You are all caught up'), findsOneWidget);
    expect(find.textContaining('2 Qaza prayers have been completed.'), findsOneWidget);
    expect(find.text('Add New Qaza'), findsOneWidget);
    expect(find.text('Recalculate Qaza'), findsOneWidget);
    expect(find.text('Complete Qaza'), findsNothing);
    expect(find.text('Continue by prayer'), findsNothing);
  });

  testWidgets('Home header opens Notifications and Profile', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());

    await tester.tap(find.byTooltip('Notifications'));
    await _pumpNavigation(tester);
    expect(find.text('Notifications'), findsOneWidget);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(find.byTooltip('Profile'), findsOneWidget);

    await tester.tap(find.byTooltip('Profile'));
    await _pumpNavigation(tester);
    expect(find.text('Account'), findsOneWidget);
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
    expect(find.text('No Qaza records yet.'), findsOneWidget);
    await tester.tap(find.text('Settings').first);
    await _pumpNavigation(tester);
    expect(find.text('Account'), findsWidgets);
    expect(find.text('Prayer & Fiqh Rules'), findsOneWidget);
  });

  testWidgets('Back from a non-root tab returns to Home instead of exiting', (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Logs').first);
    await _pumpNavigation(tester);
    expect(find.text('Logs & Progress'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await _pumpNavigation(tester);

    expect(handled, isTrue);
    expect(find.text('Logs & Progress'), findsNothing);
    expect(find.text('Start Your Qaza Journey'), findsOneWidget);
  });
}
