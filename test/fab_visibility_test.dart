import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/app_scaffold.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

final _stamp = DateTime(2026, 9, 18);

QazaRecord _record(PrayerType prayer, int day) => QazaRecord(
      id: '${prayer.name}_$day',
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      createdAt: _stamp,
      updatedAt: _stamp,
    );

void main() {
  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords(
        [for (final prayer in PrayerType.values) _record(prayer, 1)]);
    return repository;
  }

  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    InMemoryQazaRepository repository, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith((ref) =>
          Stream.value(const AppUser(id: 'u1', email: 'u1@example.com'))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const TestApp(home: WorkspaceShell()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Finder fab() => find.byKey(const Key('complete_qaza_fab'));

  bool isExtended(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(fab()).isExtended;

  group('Home list clears the FAB', () {
    testWidgets('the list reserves room below its last item', (tester) async {
      await pumpShell(tester, await ledger());

      final listView = tester.widget<ListView>(find.byType(ListView).first);
      expect((listView.padding as EdgeInsets).bottom, AppSpacing.fabClearance);
    });

    testWidgets('Witr can be scrolled clear of the FAB', (tester) async {
      await pumpShell(tester, await ledger());

      final witr = find.byKey(const Key('home_prayer_row_witr'));
      await tester.scrollUntilVisible(witr, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      // Scroll to the very end, where the overlap used to be.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      final witrRect = tester.getRect(witr);
      final fabRect = tester.getRect(fab());
      expect(witrRect.bottom, lessThanOrEqualTo(fabRect.top),
          reason: 'Witr must clear the FAB, not sit under it');
    });
  });

  group('Qaza selection bar clears the FAB', () {
    Future<void> selectFirstRecord(
        WidgetTester tester, ProviderContainer container) async {
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.qaza;
      await tester.pumpAndSettle();
      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    }

    testWidgets('the action row sits above the FAB', (tester) async {
      final container = await pumpShell(tester, await ledger());
      await selectFirstRecord(tester, container);

      final complete = find.byKey(const Key('qaza_tracker_complete_selected'));
      expect(complete, findsOneWidget);
      expect(find.byKey(const Key('qaza_tracker_clear_selection')),
          findsOneWidget);

      final actionRect = tester.getRect(complete);
      final fabRect = tester.getRect(fab());
      expect(actionRect.bottom, lessThanOrEqualTo(fabRect.top),
          reason: 'the action row must not sit under the FAB');
    });

    testWidgets('selection and completion still work', (tester) async {
      final container = await pumpShell(tester, await ledger());
      await selectFirstRecord(tester, container);
      expect(
          container.read(qazaTrackerControllerProvider).selected, hasLength(1));

      await tester.tap(find.byKey(const Key('qaza_tracker_clear_selection')));
      await tester.pumpAndSettle();

      expect(container.read(qazaTrackerControllerProvider).selected, isEmpty);
    });
  });

  group('FAB label collapses', () {
    testWidgets('it starts with icon and text', (tester) async {
      await pumpShell(tester, await ledger());

      expect(isExtended(tester), isTrue);
      expect(find.text('Complete Qaza'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('after five seconds only the icon remains', (tester) async {
      await pumpShell(tester, await ledger());

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(isExtended(tester), isFalse);
      // The icon never goes away.
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(fab(), findsOneWidget);
    });

    testWidgets('rebuilds do not restart the countdown', (tester) async {
      final container = await pumpShell(tester, await ledger());

      await tester.pump(const Duration(seconds: 3));
      // A rebuild that leaves the action visible must not extend its stay.
      container.read(qazaTrackerFilterRequestProvider.notifier).state =
          const QazaTrackerFilterRequest(prayer: PrayerType.fajr);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      await tester.pumpAndSettle();

      expect(isExtended(tester), isFalse);
    });

    testWidgets('it expands again the next time it appears', (tester) async {
      final repository = await ledger();
      final container = await pumpShell(tester, repository);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(isExtended(tester), isFalse);

      // Leaving for a destination without the action hides it...
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.settings;
      await tester.pumpAndSettle();
      expect(fab(), findsNothing);

      // ...and coming back names it again.
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.home;
      await tester.pumpAndSettle();
      expect(isExtended(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a collapsed FAB still opens Complete Qaza', (tester) async {
      await pumpShell(tester, await ledger());
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(isExtended(tester), isFalse);

      await tester.tap(fab());
      await tester.pumpAndSettle();

      expect(find.text('Complete Qaza'), findsWidgets);
      expect(find.byKey(const Key('complete_prayer_pills')), findsOneWidget);
    });
  });
}
