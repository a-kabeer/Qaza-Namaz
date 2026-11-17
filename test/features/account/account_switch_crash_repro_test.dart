import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/auth/google_sign_in_identity_provider.dart';
import 'package:qaza_namaz/data/auth/supabase_auth_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/account/guest_workspace_management_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeNativeGoogleSignInProvider implements GoogleSignInIdentityProvider {
  _FakeNativeGoogleSignInProvider({
    this.initial = const GoogleIdentitySnapshot.signedOut(),
  })  : signInResult = const GoogleIdentitySnapshot.signedIn(
          accountId: 'google-test-id',
          email: 'test@gmail.com',
          displayName: 'Test Google User',
        ),
        idToken = 'valid-id-token',
        _snapshot = initial;

  final GoogleIdentitySnapshot initial;
  final GoogleIdentitySnapshot signInResult;
  final String? idToken;
  GoogleIdentitySnapshot _snapshot;

  @override
  String? get serverClientId => null;

  @override
  bool get isSupported => true;

  @override
  Future<GoogleIdentitySnapshot> restore() async => _snapshot;

  @override
  Future<GoogleIdentitySnapshot> signIn() async => signInResult;

  @override
  Future<({GoogleIdentitySnapshot snapshot, String? idToken})>
      signInWithTokens() async {
    _snapshot = signInResult;
    return (snapshot: signInResult, idToken: idToken);
  }

  @override
  Future<void> signOut() async {
    _snapshot = const GoogleIdentitySnapshot.signedOut();
  }
}

class _FakeSupabaseAuthService extends SupabaseAuthService {
  _FakeSupabaseAuthService();

  @override
  bool get isSupported => true;

  @override
  Future<AuthOperationResult> signInWithGoogleNative({
    required String idToken,
    String? accessToken,
  }) async {
    final user = User(
      id: 'google-supabase-uid-12345',
      appMetadata: {},
      userMetadata: {'full_name': 'Test Google User'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'test@gmail.com',
    );
    final session = Session(
      accessToken: 'fake-access-token',
      tokenType: 'bearer',
      user: user,
    );
    return AuthOperationResult.success(user: user, session: session);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Account switching: Guest A with data -> Guest B -> Google Sign-In -> repeated 5 switches with workspace isolation',
      (tester) async {
    FlutterErrorDetails? caughtDetails;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
      debugPrint('CAUGHT DETAILS: ${details.exception}');
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    await session.initialize();

    // 1. Create Guest A with Profile and Qaza records
    final guestA = session.activeLocalAccountId!;
    final now = DateTime(2026, 1, 1);
    final profileA = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1990, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    await store.saveProfile(guestA, profileA);
    await database.markAccountChoiceComplete();
    await database.setOnboardingCompletedInTransaction(true);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseManagerProvider.overrideWithValue(manager),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(_FakeNativeGoogleSignInProvider()),
        supabaseAuthServiceProvider.overrideWithValue(_FakeSupabaseAuthService()),
        prayerTimeClockProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    // Add Qaza record in Guest A
    final localStore = container.read(qazaLocalStoreProvider);
    await localStore.saveRecords(guestA, [
      QazaRecord(
        id: 'rec-1',
        userId: guestA,
        prayerType: PrayerType.fajr,
        originalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
      QazaRecord(
        id: 'rec-2',
        userId: guestA,
        prayerType: PrayerType.zuhr,
        originalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    // Pump root app
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StartupGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Open GuestWorkspaceManagementScreen and create Guest Account B with no profile
    final navContext = tester.element(find.byType(WorkspaceShell));
    Navigator.of(navContext).push<void>(
      MaterialPageRoute(builder: (_) => const GuestWorkspaceManagementScreen()),
    );
    await tester.pumpAndSettle();

    // Tap "+ Create New Profile" to create Guest B
    await tester.tap(find.text('+ Create New Profile'));
    await tester.pumpAndSettle();

    final guestB = session.activeLocalAccountId!;
    expect(guestB, isNot(guestA));

    // 3. Now navigate to Account Settings
    Navigator.of(tester.element(find.byType(StartupGate))).push<void>(
      MaterialPageRoute(builder: (_) => const AccountScreen()),
    );
    await tester.pumpAndSettle();

    // 4. Tap Google Sign In
    final googleLoginBtn = find.byKey(const Key('account_google_login'));
    expect(googleLoginBtn, findsOneWidget);

    await tester.tap(googleLoginBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    debugPrint('=== RESULT: caughtDetails = ${caughtDetails?.exception} ===');
    expect(caughtDetails, isNull);

    final googleWorkspaceId = session.activeLocalAccountId!;
    expect(googleWorkspaceId.startsWith('supabase_'), isTrue);

    // 5. Verify Workspace Isolation
    final recordsA = await localStore.getPage(userId: guestA);
    final recordsB = await localStore.getPage(userId: guestB);
    final recordsGoogle = await localStore.getPage(userId: googleWorkspaceId);

    expect(recordsA.records.length, 2, reason: 'Guest A records must remain untouched');
    expect(recordsB.records.length, 0, reason: 'Guest B must have 0 records');
    expect(recordsGoogle.records.length, 0, reason: 'Google workspace must have 0 records');

    // 6. Repeat Account Switching 5 times in a loop
    for (int cycle = 1; cycle <= 5; cycle++) {
      debugPrint('--- Account switch cycle $cycle ---');

      // Switch to Guest A
      await session.activateLocalAccount(guestA);
      await tester.pumpAndSettle();
      expect(session.activeLocalAccountId, guestA);
      expect((await localStore.getPage(userId: guestA)).records.length, 2);

      // Switch to Guest B
      await session.activateLocalAccount(guestB);
      await tester.pumpAndSettle();
      expect(session.activeLocalAccountId, guestB);
      expect((await localStore.getPage(userId: guestB)).records.length, 0);

      // Switch to Google Workspace
      await session.activateLocalAccount(googleWorkspaceId);
      await tester.pumpAndSettle();
      expect(session.activeLocalAccountId, googleWorkspaceId);
      expect((await localStore.getPage(userId: googleWorkspaceId)).records.length, 0);

      expect(caughtDetails, isNull, reason: 'No crash allowed during cycle $cycle');
    }

    // Restore FlutterError.onError before test finishes
    FlutterError.onError = originalOnError;

    // Drain any remaining ticking clock timers
    await tester.pump(const Duration(seconds: 2));

    expect(caughtDetails, isNull);
  });
}
