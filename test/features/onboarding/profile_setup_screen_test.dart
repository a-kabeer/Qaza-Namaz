import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/repositories/qaza_plan_revision_repository.dart';
import 'package:qaza_namaz/domain/services/current_day_qaza_eligibility_service.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Future<(AppDatabase, AccountSessionManager)> _readyGuestSession() async {
  final database = AppDatabase(NativeDatabase.memory());
  final store = AccountLocalStore(database: database);
  await store.ensureInitialized(
    hasLegacyProfile: false,
    hasLegacyQaza: false,
  );
  await store.ensureGuestActive();

  final firebase = FirebaseServices();
  final backup = FirebaseBackupService(
    firebase: firebase,
    database: database,
    accountStore: store,
  );
  final reconciliation = FirebaseReconciliationService(
    firebase: firebase,
    backupService: backup,
    accountStore: store,
    database: database,
  );
  final manager = AccountSessionManager(
    accountStore: store,
    firebase: firebase,
    auth: GoogleFirebaseAuthService(firebase),
    backup: backup,
    reconciliation: reconciliation,
  );
  await manager.initialize();
  return (database, manager);
}

class _FakeUserProfileRepository implements UserProfileRepository {
  UserProfile? stored;
  int saveCount = 0;

  @override
  Future<UserProfile?> load() async => stored;

  @override
  Future<void> save(UserProfile profile) async {
    stored = profile;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class _OneDayQazaPlanService extends QazaPlanService {
  _OneDayQazaPlanService();

  @override
  QazaPlan? planFor(UserProfile profile) {
    return QazaPlan(
      startDate: DateTime(2012, 1, 1),
      endDate: DateTime(2012, 1, 2),
      totalDays: 1,
      includeWitr: false,
      totalPrayers: 5,
      prayerBreakdown: {
        for (final prayer in PrayerType.values)
          if (prayer != PrayerType.witr) prayer: 1,
      },
    );
  }
}

class _FakeQazaPlanRevisionRepository
    implements QazaPlanRevisionRepository {
  QazaPlanRevision? stored;

  @override
  Future<QazaPlanRevision?> latest(String userId) async => stored;

  @override
  Future<void> save(QazaPlanRevision revision) async {
    stored = revision;
  }
}


void main() {
  late AppDatabase database;
  late AccountSessionManager sessionManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    (database, sessionManager) = await _readyGuestSession();
  });

  tearDown(() => database.close());

  testWidgets(
    'profile onboarding imports Qaza after activating the saved local ledger',
    (tester) async {
      final initialProfile = UserProfile(
        languageCode: 'en',
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(2000, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 15,
        witrIncluded: true,
        onboardingCompleted: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            accountSessionManagerProvider.overrideWith((ref) => sessionManager),
            activeLocalAccountIdStateProvider.overrideWith(
              (ref) => UserProfile.localLedgerUserId,
            ),
          userProfileRepositoryProvider.overrideWithValue(repository),
            qazaPlanServiceProvider.overrideWithValue(
              _OneDayQazaPlanService(),
            ),
            qazaImportProvider.overrideWith(
              () => importController,
            ),
            qazaPlanRevisionRepositoryProvider.overrideWithValue(
              _FakeQazaPlanRevisionRepository(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileSetupScreen(
              languageCode: 'en',
              initialProfile: initialProfile,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('profile_gender')),
          matching: find.text('Male'),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_submit')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_submit')));
      // ProfileForm keeps its saving indicator active while the review dialog
      // is open, so pumpAndSettle() would wait forever on that animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('qaza_review_add')), findsOneWidget);

      await tester.tap(find.byKey(const Key('qaza_review_add')));
      for (var i = 0;
          i < 20 && find.byType(WorkspaceShell).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(WorkspaceShell), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      final profileRows = await database.customSelect(
        '''SELECT payload_json FROM account_profiles
           WHERE local_account_id = ?''',
        variables: [Variable(UserProfile.localLedgerUserId)],
      ).get();
      expect(profileRows, hasLength(1));
      expect(
        UserProfile.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(profileRows.single.read<String>('payload_json')),
          ),
        ).onboardingCompleted,
        isTrue,
      );
      expect(
        await database.customSelect(
          '''SELECT id FROM qaza_records WHERE user_id = ?''',
          variables: [Variable(UserProfile.localLedgerUserId)],
        ).get(),
        hasLength(5),
      );
    },
  );


  testWidgets(
    'zero-Qaza onboarding completes directly from Profile Setup without review or import',
    (tester) async {
      final initialProfile = UserProfile(
        languageCode: 'en',
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(2000, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 12,
        witrIncluded: true,
        onboardingCompleted: false,
      );

      final calculatedPlan = const QazaPlanService().planFor(initialProfile);
      expect(calculatedPlan, isNotNull);
      expect(calculatedPlan!.startDate, calculatedPlan.endDate);
      expect(calculatedPlan.totalWithWitr, 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            accountSessionManagerProvider.overrideWith((ref) => sessionManager),
            activeLocalAccountIdStateProvider.overrideWith(
              (ref) => UserProfile.localLedgerUserId,
            ),
          userProfileRepositoryProvider.overrideWithValue(repository),
            qazaPlanServiceProvider.overrideWithValue(
              const QazaPlanService(),
            ),
            qazaImportProvider.overrideWith(
              () => importController,
            ),
            qazaPlanRevisionRepositoryProvider.overrideWithValue(
              _FakeQazaPlanRevisionRepository(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileSetupScreen(
              languageCode: 'en',
              initialProfile: initialProfile,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileSetupScreen), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_submit')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_submit')));
      await tester.pump();

      for (var i = 0;
          i < 20 && find.byType(WorkspaceShell).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const Key('qaza_review_add')), findsNothing);
      expect(find.byType(WorkspaceShell), findsOneWidget);
      final profileRows = await database.customSelect(
        '''SELECT payload_json FROM account_profiles
           WHERE local_account_id = ?''',
        variables: [Variable(UserProfile.localLedgerUserId)],
      ).get();
      expect(profileRows, hasLength(1));
      expect(
        UserProfile.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(profileRows.single.read<String>('payload_json')),
          ),
        ).onboardingCompleted,
        isTrue,
      );
      expect(
        await database.customSelect(
          '''SELECT COUNT(*) AS count FROM account_plan_revisions
             WHERE local_account_id = ?''',
          variables: [Variable(UserProfile.localLedgerUserId)],
        ).getSingle().then((row) => row.read<int>('count')),
        1,
      );
    },
  );

  testWidgets(
    'completed zero-Qaza profile resolves to Home through StartupGate',
    (tester) async {
      final repository = _FakeUserProfileRepository();
      final profile = UserProfile(
        languageCode: 'en',
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(2000, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 12,
        witrIncluded: true,
        onboardingCompleted: true,
      );
      repository.stored = profile;

      final plan = const QazaPlanService().planFor(profile);
      expect(plan, isNotNull);
      expect(plan!.totalWithWitr, 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            accountSessionManagerProvider.overrideWith((ref) => sessionManager),
            activeLocalAccountIdStateProvider.overrideWith(
              (ref) => UserProfile.localLedgerUserId,
            ),
            userProfileRepositoryProvider.overrideWithValue(repository),
            progressSummaryProvider.overrideWith(
              (ref) async => QazaProgressSummary.empty(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StartupGate(),
          ),
        ),
      );

      await tester.pump();
      for (var i = 0;
          i < 20 && find.byType(WorkspaceShell).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(WorkspaceShell), findsOneWidget);
      for (var i = 0;
          i < 20 && find.byKey(const Key('home_empty_state')).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
    },
  );

  testWidgets(
    'StartupGate opens Profile Setup for an incomplete profile',
    (tester) async {
      final repository = _FakeUserProfileRepository();
      repository.stored = const UserProfile(
        languageCode: 'en',
        onboardingCompleted: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            accountSessionManagerProvider.overrideWith((ref) => sessionManager),
            activeLocalAccountIdStateProvider.overrideWith(
              (ref) => UserProfile.localLedgerUserId,
            ),
            userProfileRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StartupGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    },
  );


}
