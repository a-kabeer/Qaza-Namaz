import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/data_management/qaza_data_management_screen.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Future<AccountSessionManager> _createSession(AppDatabase database) async {
  final store = AccountLocalStore(database: database);
  final manager = AccountSessionManager(accountStore: store);
  await manager.initialize();
  return manager;
}

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('account omits redundant device and progress intro cards',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pump();

    expect(find.text('This device'), findsNothing);
    expect(find.text('Your data is stored on this device'), findsNothing);
    expect(find.text('Keep your progress safe'), findsNothing);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Automatic backup'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('Account owns data management and reset actions', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_data_management')), findsOneWidget);
    expect(find.byKey(const Key('account_reset_qaza_counter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account_data_management')));
    await tester.pumpAndSettle();

    expect(find.byType(QazaDataManagementScreen), findsOneWidget);
  });

  testWidgets('settings account entry remains local-only', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const SettingsScreen()));
    await tester.pump();

    expect(find.text('Local • This device only'), findsOneWidget);
    expect(find.text('Signed in with Google'), findsNothing);
    expect(find.text('Connect Google'), findsNothing);
    expect(find.byKey(const Key('account_data_management')), findsNothing);
    expect(find.byKey(const Key('account_reset_qaza_counter')), findsNothing);
  });
}
