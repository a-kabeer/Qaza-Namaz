import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';
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
  Future<void> pumpWorkspace(
      WidgetTester tester, InMemoryQazaRepository repository) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        authStateProvider.overrideWith((ref) => Stream.value(
            const AppUser(id: 'test-user', email: 'test@example.com'))),
      ],
      child: const TestApp(home: WorkspaceShell()),
    ));
    await _pumpNavigation(tester);
    await tester.pumpAndSettle();
  }

  Future<void> revealPrayerLedger(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -500));
    await _pumpNavigation(tester);
  }

  testWidgets('Workspace exposes four primary navigation destinations',
      (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    expect(find.text('Home').first, findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Qaza'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    // Home leads with the progress overview and its two quick actions.
    expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
    expect(find.byKey(const Key('home_calculate_qaza')), findsOneWidget);
    expect(find.byKey(const Key('home_add_qaza')), findsOneWidget);
    await revealPrayerLedger(tester);
    expect(find.byKey(const Key('home_prayer_row_fajr')), findsOneWidget);
  });

  testWidgets('Home derives live totals from the aggregate repository summary',
      (tester) async {
    final repository = InMemoryQazaRepository();
    final now = DateTime(2026, 9, 13);
    await repository.addRecords([
      QazaRecord(
          id: 'test_fajr_2026-09-01',
          userId: 'test-user',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 1),
          createdAt: now,
          updatedAt: now),
      QazaRecord(
          id: 'test_zuhr_2026-09-02',
          userId: 'test-user',
          prayerType: PrayerType.zuhr,
          originalDate: DateTime(2026, 9, 2),
          status: QazaStatus.completed,
          completedAt: now,
          createdAt: now,
          updatedAt: now),
    ]);
    await pumpWorkspace(tester, repository);
    // One pending, one completed: the overview counts and the overall ring
    // both come from the aggregate summary.
    expect(
        tester.widget<Text>(find.byKey(const Key('home_pending_value'))).data,
        '1');
    expect(find.text('50%'), findsWidgets);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets(
      'Selecting Qaza, Calculator and Settings preserves destination state',
      (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Calculator').first);
    await _pumpNavigation(tester);
    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Qaza').first);
    await _pumpNavigation(tester);
    await _pumpNavigation(tester);
    expect(find.byKey(const Key('qaza_tracker_status_filter')), findsOneWidget);
    expect(find.byKey(const Key('qaza_tracker_empty')), findsOneWidget);
    await tester.tap(find.text('Settings').first);
    await _pumpNavigation(tester);
    expect(find.text('Account'), findsWidgets);
    // Prayer rules moved to the Knowledge tab; Settings is configuration only.
    expect(find.text('Prayer & Fiqh Rules'), findsNothing);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Backup & Data'), findsOneWidget);
  });

  testWidgets('Back from a non-root tab returns to Home instead of exiting',
      (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Qaza').first);
    await _pumpNavigation(tester);
    await _pumpNavigation(tester);
    expect(find.byKey(const Key('qaza_tracker_status_filter')), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await _pumpNavigation(tester);

    expect(handled, isTrue);
    expect(find.byKey(const Key('qaza_tracker_status_filter')), findsNothing);
    expect(find.text('Home').first, findsOneWidget);
  });
}
