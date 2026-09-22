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

  testWidgets('Workspace exposes five primary navigation destinations',
      (tester) async {
    // A record of some kind, or Home shows its empty state instead of the
    // dashboard this test is about.
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      QazaRecord(
          id: 'test_fajr_2026-09-01',
          userId: 'test-user',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 13),
          updatedAt: DateTime(2026, 9, 13)),
    ]);
    await pumpWorkspace(tester, repository);
    expect(find.text('Home').first, findsOneWidget);
    expect(find.text('Qaza'), findsWidgets);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Prayer Times'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // Calculator remains contextual; Prayer Times is a primary destination.
    expect(find.text('Calculator'), findsNothing);
    // Home leads with the compact progress overview; Qaza actions live on the Qaza workspace.
    expect(find.byKey(const Key('home_dashboard')), findsOneWidget);
    
    expect(find.byKey(const Key('qaza_tracker_add_fab')), findsOneWidget);
    expect(find.byKey(const Key('home_overall_qaza')), findsOneWidget);
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
    // One pending, one completed: the compact summary comes from the
    // aggregate repository state.
    expect(
      tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('home_completed_value')),
          matching: find.byType(Text),
        ).last,
      ).data,
      '1',
    );
    expect(
      tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('home_pending_value')),
          matching: find.byType(Text),
        ).last,
      ).data,
      '1',
    );
    expect(
      tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('home_total_value')),
          matching: find.byType(Text),
        ).last,
      ).data,
      '2',
    );
  });

  testWidgets('Qaza is a primary destination and Back returns to Home', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      QazaRecord(
          id: 'test_fajr_2026-09-01',
          userId: 'test-user',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 13),
          updatedAt: DateTime(2026, 9, 13)),
    ]);
    await pumpWorkspace(tester, repository);

    await tester.tap(find.text('Qaza').first);
    await _pumpNavigation(tester);
    expect(find.byKey(const Key('qaza_tracker_filter_button')), findsOneWidget);
    expect(find.byKey(const Key('qaza_tracker_sort')), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await _pumpNavigation(tester);
    expect(handled, isTrue);
    expect(find.byKey(const Key('home_dashboard')), findsOneWidget);
  });

  testWidgets('Selecting Knowledge and Settings preserves destination state',
      (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Knowledge').first);
    await _pumpNavigation(tester);
    await _pumpNavigation(tester);
    expect(find.text('Knowledge Base'), findsWidgets);
    await tester.tap(find.text('Settings').first);
    await _pumpNavigation(tester);
    expect(find.text('Account'), findsWidgets);
    // Prayer rules moved to the Knowledge tab; Settings is configuration only.
    expect(find.text('Prayer & Fiqh Rules'), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Data & Storage'), findsOneWidget);
  });

  testWidgets('Back from a non-root tab returns to Home instead of exiting',
      (tester) async {
    await pumpWorkspace(tester, InMemoryQazaRepository());
    await tester.tap(find.text('Knowledge').first);
    await _pumpNavigation(tester);
    await _pumpNavigation(tester);
    expect(find.text('Knowledge Base'), findsWidgets);

    final handled = await tester.binding.handlePopRoute();
    await _pumpNavigation(tester);

    expect(handled, isTrue);
    expect(find.text('Knowledge Base'), findsNothing);
    expect(find.text('Home').first, findsOneWidget);
  });
}
