import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/account/guest_workspace_management_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Widget _app(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Scenario 17 — the Guest workspace delete confirmation shows what will
/// be lost: the profile plus the counts of Qaza records and daily Salah
/// records owned by that workspace.
void main() {
  late AppDatabase database;
  late AccountLocalStore store;
  late AccountSessionManager manager;
  late String activeId;
  late String manyRecordsId;
  late String emptyId;
  late String singleRecordId;

  Future<void> seedQazaRecords(String userId, int count) async {
    for (var i = 1; i <= count; i++) {
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: '${userId}_fajr_$i',
          userId: userId,
          prayerType: PrayerType.fajr.name,
          originalDate: DateTime(2025, 1, i),
          status: QazaStatus.pending.name,
          createdAt: DateTime(2025, 1, i),
          updatedAt: DateTime(2025, 1, i),
        ),
      );
    }
  }

  Future<void> seedDailySalahLogs(String userId, int count) async {
    for (var i = 1; i <= count; i++) {
      await database.customInsert(
        '''INSERT INTO daily_salah_logs
           (user_id, prayer_date, prayer_type, status,
            tracker_created_qaza_id, linked_qaza_id, completion_sync_id,
            updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable.withString(userId),
          Variable.withString('2025-02-0$i'),
          Variable.withString('fajr'),
          Variable.withString('missed'),
          Variable.withString('${userId}_fajr_$i'),
          Variable.withString('${userId}_fajr_$i'),
          Variable.withString('sync-$userId-$i'),
          Variable.withString(DateTime.utc(2025, 2, i).toIso8601String()),
        ],
      );
    }
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    manager = AccountSessionManager(accountStore: store);
    await manager.initialize();
    activeId = manager.activeLocalAccountId!;

    manyRecordsId =
        await store.createGuestWorkspace(displayName: 'Fatima Records');
    await seedQazaRecords(manyRecordsId, 3);
    await seedDailySalahLogs(manyRecordsId, 2);

    singleRecordId =
        await store.createGuestWorkspace(displayName: 'Single Record');
    await seedQazaRecords(singleRecordId, 1);
    await seedDailySalahLogs(singleRecordId, 1);

    emptyId = await store.createGuestWorkspace(displayName: 'Empty One');

    // Deletion is only offered for non-active workspaces.
    await manager.activateLocalAccount(activeId);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        accountLocalStoreProvider.overrideWith((ref) => store),
        accountSessionManagerProvider.overrideWith((ref) => manager),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(container, const GuestWorkspaceManagementScreen()),
    );
    // The screen loads workspaces asynchronously; pump in bounded steps
    // until the seeded workspaces are listed.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(Key('guest_workspace_$manyRecordsId'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(Key('guest_workspace_$manyRecordsId')),
      findsOneWidget,
    );
  }

  Future<void> openDeleteConfirmation(
    WidgetTester tester,
    String workspaceId,
  ) async {
    final tile = find.byKey(Key('guest_workspace_$workspaceId'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    // Record counts are loaded asynchronously before the dialog opens.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(AlertDialog).evaluate().isNotEmpty) break;
    }
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete Guest workspace?'), findsOneWidget);
  }

  Future<void> dismissConfirmation(WidgetTester tester) async {
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }

  testWidgets('delete confirmation shows Qaza and daily Salah counts',
      (tester) async {
    await pumpScreen(tester);

    await openDeleteConfirmation(tester, manyRecordsId);
    expect(find.textContaining('removes its profile'), findsOneWidget);
    expect(find.textContaining('3 Qaza records'), findsOneWidget);
    expect(find.textContaining('2 daily Salah records'), findsOneWidget);
    // The seven-day undo explanation is still present.
    expect(find.textContaining('kept for seven days'), findsOneWidget);
    await dismissConfirmation(tester);

    // Cancelling must not have scheduled any deletion.
    expect(
      (await store.getAccount(manyRecordsId))?.lifecycleState,
      AccountLifecycleState.active,
    );
  });

  testWidgets('delete confirmation shows zero counts for an empty workspace',
      (tester) async {
    await pumpScreen(tester);

    await openDeleteConfirmation(tester, emptyId);
    expect(find.textContaining('0 Qaza records'), findsOneWidget);
    expect(find.textContaining('0 daily Salah records'), findsOneWidget);
    await dismissConfirmation(tester);
  });

  testWidgets('delete confirmation uses singular wording for one record',
      (tester) async {
    await pumpScreen(tester);

    await openDeleteConfirmation(tester, singleRecordId);
    expect(
      find.textContaining('1 Qaza record and 1 daily Salah record'),
      findsOneWidget,
    );
    await dismissConfirmation(tester);
  });

  // Scenario 18 — an abandoned empty draft (no name, no data) is hidden
  // from the management list; it is listed only once it holds data.
  testWidgets(
      'an abandoned empty draft is not shown in the management '
      'list', (tester) async {
    final hiddenDraftId = await store.createGuestWorkspace(draft: true);
    await manager.activateLocalAccount(activeId);

    await pumpScreen(tester);

    expect(
      find.byKey(Key('guest_workspace_$hiddenDraftId')),
      findsNothing,
    );
    expect(find.byKey(Key('guest_workspace_$manyRecordsId')), findsOneWidget);
    // The draft itself still exists and remains resumable.
    expect(
      (await store.getAccount(hiddenDraftId))?.lifecycleState,
      AccountLifecycleState.draft,
    );
  });

  // Scenario 17 — rename changes only the display name: driving the
  // rename dialog end to end updates the management list (and any chooser
  // built on the same listing) to show the new name under the unchanged
  // workspace ID, and the dialog's exit animation completes without the
  // "TextEditingController used after being disposed" assertion the old
  // dispose-on-pop implementation tripped.
  testWidgets('rename dialog flow renames the workspace in the management list',
      (tester) async {
    await pumpScreen(tester);

    final tile = find.byKey(Key('guest_workspace_$manyRecordsId'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Rename Guest workspace'), findsOneWidget);
    final nameField = find.byType(TextField);
    expect(nameField, findsOneWidget);
    expect(
      tester.widget<TextField>(nameField).controller?.text,
      'Fatima Records',
    );

    await tester.enterText(nameField, 'Fatima Renamed');
    await tester.tap(find.text('Continue'));

    // The rename is saved and the list reloads asynchronously; pump in
    // bounded steps until the tile carries the new name.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .descendant(of: tile, matching: find.text('Fatima Renamed'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    // Let the dialog exit animation run to completion with the field
    // still mounted — the point where a disposed controller asserts.
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(of: tile, matching: find.text('Fatima Renamed')),
      findsOneWidget,
    );
    expect(find.text('Fatima Records'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      (await store.getAccount(manyRecordsId))?.displayName,
      'Fatima Renamed',
    );
    expect(
      (await store.getAccount(manyRecordsId))?.localAccountId,
      manyRecordsId,
    );
  });

  test(
      'rename updates the listed display name without changing the '
      'workspace ID', () async {
    await store.saveWorkspaceDisplayName(manyRecordsId, 'Renamed Guest');

    final listed = await store.listGuestWorkspaces();
    final entry = listed.singleWhere(
      (account) => account.localAccountId == manyRecordsId,
    );
    expect(entry.displayName, 'Renamed Guest');
    expect(
      (await store.getAccount(manyRecordsId))?.localAccountId,
      manyRecordsId,
    );
  });

  test('countWorkspaceRecords counts only the requested workspace', () async {
    final many = await store.countWorkspaceRecords(manyRecordsId);
    expect(many.qazaRecords, 3);
    expect(many.dailySalahRecords, 2);

    final single = await store.countWorkspaceRecords(singleRecordId);
    expect(single.qazaRecords, 1);
    expect(single.dailySalahRecords, 1);

    final empty = await store.countWorkspaceRecords(emptyId);
    expect(empty.qazaRecords, 0);
    expect(empty.dailySalahRecords, 0);

    final active = await store.countWorkspaceRecords(activeId);
    expect(active.qazaRecords, 0);
    expect(active.dailySalahRecords, 0);
  });
}
