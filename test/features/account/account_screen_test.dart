import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeIdentityProvider implements GoogleIdentityProvider {
  _FakeIdentityProvider({
    this.initial = const GoogleIdentitySnapshot.signedOut(),
    this.signInResult =
        const GoogleIdentitySnapshot.failed('Test sign-in failure'),
  }) : _snapshot = initial;

  final GoogleIdentitySnapshot initial;
  final GoogleIdentitySnapshot signInResult;
  GoogleIdentitySnapshot _snapshot;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<GoogleIdentitySnapshot> restore() async => _snapshot;

  @override
  Future<GoogleIdentitySnapshot> signIn() async {
    signInCalls++;
    _snapshot = signInResult;
    return _snapshot;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _snapshot = const GoogleIdentitySnapshot.signedOut();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'account shows Google identity controls and local data tools only',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    final identity = _FakeIdentityProvider();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseManagerProvider.overrideWithValue(manager),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(identity),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    await session.initialize();
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('account_google_profile_card')), findsOneWidget);
    expect(find.byKey(const Key('account_google_login')), findsOneWidget);
    expect(find.byKey(const Key('account_guest_workspace_management')),
        findsOneWidget);
    expect(find.byKey(const Key('account_data_management')), findsOneWidget);
    expect(find.byKey(const Key('account_reset_qaza_counter')), findsOneWidget);
    expect(find.byKey(const Key('account_cloud_backup')), findsNothing);
    expect(find.textContaining('Backup Now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google sign-in failure leaves local workspace unchanged',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    final identity = _FakeIdentityProvider();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseManagerProvider.overrideWithValue(manager),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(identity),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    await session.initialize();
    final originalWorkspace = session.activeLocalAccountId;
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_google_login')));
    await tester.pumpAndSettle();

    expect(identity.signInCalls, 1);
    expect(session.activeLocalAccountId, originalWorkspace);
    expect(find.byKey(const Key('account_google_login')), findsOneWidget);
    expect(find.byKey(const Key('account_cloud_backup')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
