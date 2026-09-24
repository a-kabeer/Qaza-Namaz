import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/domain/services/guest_migration_service.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/auth/guest_session.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'package:qaza_namaz/features/prayer_times/presentation/prayer_times_setup_prompt.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// Signing in from Settings, and what the app is allowed to do about it.
///
/// Two defects are pinned here. Settings reported exactly two outcomes —
/// "signed in, N records added" or "sign-in failed" — so a guest who still
/// owed a Merge / Use Account / Keep Guest decision was told the migration was
/// done before they had chosen, a cancellation was reported as a failure, and
/// a real error (an unregistered SHA-1, say) was replaced by a generic line
/// nobody can act on. And any failure left `AuthGate` holding
/// `error != null && isGuest`, which swapped the whole app for the startup
/// Authentication navigator — throwing the user out of the screen they were
/// on, with no way back to what they were doing.
const _account = AppUser(id: 'account-1', email: 'user@example.com');
final _stamp = DateTime(2026, 9, 18);

QazaRecord _guestRecord(int day) => QazaRecord(
      id: 'guest_fajr_$day',
      userId: guestUserId,
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 1, day),
      createdAt: _stamp,
      updatedAt: _stamp,
    );

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  Object? signInFailure;
  int signInCalls = 0;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    signInCalls++;
    final failure = signInFailure;
    if (failure != null) throw failure;
    _current = _account;
    _controller.add(_account);
    return _account;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

class _NoopLocalStore extends QazaLocalStore {
  @override
  Future<OfflineCacheSnapshot> load() async => const OfflineCacheSnapshot();
  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {}
  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {}
  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {}
  @override
  Future<void> retireUserData({required String userId}) async {}
}

class _FakeMigration extends GuestMigrationService {
  _FakeMigration({required this.guestData})
      : super(
          localStore: _NoopLocalStore(),
          remoteRepository: InMemoryQazaRepository(),
        );

  bool guestData;
  int migrateCalls = 0;
  int retireCalls = 0;

  @override
  Future<bool> hasGuestData({required String guestUserId}) async => guestData;

  @override
  Future<GuestMigrationResult> migrate({
    required String guestUserId,
    required String accountUserId,
    DateTime? completedAt,
  }) async {
    migrateCalls++;
    return const GuestMigrationResult(examined: 3, added: 2, completed: 1);
  }

  @override
  Future<void> retireGuestData({required String guestUserId}) async {
    retireCalls++;
    guestData = false;
  }
}

void main() {
  late _FakeAuthRepository auth;
  late _FakeMigration migration;
  late InMemoryQazaRepository ledger;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      GuestSessionNotifier.storageKey: true,
      // The prayer-times setup dialog otherwise opens over the screen and
      // swallows every tap; it has its own tests.
      PrayerTimesSetupPromptPreferences.storageKey: true,
    });
    auth = _FakeAuthRepository();
    migration = _FakeMigration(guestData: true);
    ledger = InMemoryQazaRepository();
    addTearDown(auth.dispose);
  });

  List<Override> overrides() => [
        qazaRepositoryProvider.overrideWithValue(ledger),
        authRepositoryProvider.overrideWithValue(auth),
        guestMigrationServiceProvider.overrideWithValue(migration),
      ];

  /// Mounts Settings as a guest, the way the workspace hosts it.
  ///
  /// Settings itself rather than the whole shell: the shell keeps every
  /// destination alive inside an `IndexedStack`, so a tap aimed at one that is
  /// not in front never lands. `AuthGate`'s own behaviour is covered
  /// separately, in the last group.
  Future<ProviderContainer> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    // Keep the guest session and the upgrade controller alive for the whole
    // journey, as the running app's widget tree does.
    container.listen(guestSessionProvider, (_, __) {});
    container.listen(guestUpgradeControllerProvider, (_, __) {});
    await container.read(guestSessionProvider.notifier).ensureRestored();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const TestApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    final row = find.byKey(const Key('settings_backup_sign_in'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// Still on Settings, whatever the sign-in did.
  ///
  /// The backup row itself is guest-only and correctly disappears once the
  /// account is live, so the screen is what gets checked, not the row.
  bool onSettings(WidgetTester tester) =>
      find.byType(SettingsScreen).evaluate().isNotEmpty &&
      find.byType(AuthenticationScreen).evaluate().isEmpty;

  group('a guest with nothing to migrate', () {
    testWidgets('signs in and is told so, without leaving Settings',
        (tester) async {
      migration.guestData = false;
      await openSettings(tester);

      await tapSignIn(tester);

      // No decision is owed, so none is asked for.
      expect(find.byType(AuthenticationScreen), findsNothing);
      expect(find.byKey(const Key('backup_sign_in_done')), findsOneWidget);
      expect(migration.migrateCalls, 0);
      expect(onSettings(tester), isTrue);
    });
  });

  group('a guest with records owes a decision first', () {
    testWidgets('the choice is offered, and nothing claims to be done yet',
        (tester) async {
      await ledger.addRecords([_guestRecord(1), _guestRecord(2)]);
      final container = await openSettings(tester);

      await tapSignIn(tester);

      expect(find.byKey(const Key('guest_decision_merge')), findsOneWidget);
      expect(
          find.byKey(const Key('guest_decision_use_account')), findsOneWidget);
      expect(
          find.byKey(const Key('guest_decision_keep_guest')), findsOneWidget);
      // Nothing has been migrated, so nothing may say it has.
      expect(find.byKey(const Key('backup_sign_in_done')), findsNothing);
      expect(migration.migrateCalls, 0);
      expect(
        container.read(guestUpgradeControllerProvider).origin,
        GuestUpgradeOrigin.inApp,
      );
    });

    testWidgets('Merge migrates, then returns to Settings', (tester) async {
      await ledger.addRecords([_guestRecord(1)]);
      await openSettings(tester);
      await tapSignIn(tester);

      await tester.tap(find.byKey(const Key('guest_decision_merge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('merge_data')));
      await tester.pumpAndSettle();

      expect(migration.migrateCalls, 1);
      expect(migration.retireCalls, 1);
      expect(onSettings(tester), isTrue,
          reason: 'the user came from Settings and belongs back on it');
      expect(find.byKey(const Key('backup_sign_in_done')), findsOneWidget);
      expect(find.text('Signed in. 2 records were added to your account.'),
          findsOneWidget);
    });

    testWidgets('Use Account Data retires guest records and returns',
        (tester) async {
      await ledger.addRecords([_guestRecord(1)]);
      await openSettings(tester);
      await tapSignIn(tester);

      await tester.tap(find.byKey(const Key('guest_decision_use_account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('use_account_data')));
      await tester.pumpAndSettle();

      expect(migration.migrateCalls, 0, reason: 'nothing is ever auto-merged');
      expect(migration.retireCalls, 1);
      expect(onSettings(tester), isTrue);
      expect(find.byKey(const Key('backup_sign_in_done')), findsOneWidget);
    });

    testWidgets('Keep Guest Data leaves the guest ledger untouched',
        (tester) async {
      await ledger.addRecords([_guestRecord(1)]);
      final container = await openSettings(tester);
      await tapSignIn(tester);

      await tester.tap(find.byKey(const Key('guest_decision_keep_guest')));
      await tester.pumpAndSettle();

      expect(migration.migrateCalls, 0);
      expect(migration.retireCalls, 0, reason: 'guest data must survive');
      expect(container.read(isGuestProvider), isTrue);
      expect(onSettings(tester), isTrue);
      // Keeping guest data is an explicit user decision, not an auth failure.
      expect(find.byKey(const Key('backup_sign_in_failed')), findsNothing);
      expect(find.byKey(const Key('backup_sign_in_cancelled')), findsOneWidget);
    });
  });

  group('when sign-in does not succeed', () {
    testWidgets('a Google cancellation is surfaced with configuration guidance',
        (tester) async {
      auth.signInFailure = const AuthenticationCancelledException();
      final container = await openSettings(tester);

      await tapSignIn(tester);

      expect(find.byKey(const Key('backup_sign_in_failed')), findsOneWidget);
      expect(
        find.textContaining('SHA-1/SHA-256'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('backup_sign_in_cancelled')), findsNothing);
      expect(container.read(isGuestProvider), isTrue);
      expect(onSettings(tester), isTrue);
    });

    testWidgets('the real diagnostic is shown, not a generic line',
        (tester) async {
      auth.signInFailure = const AuthenticationException(
        source: 'google-sign-in',
        code: 'missing-id-token',
        message: 'Google Sign-In completed without an ID token.',
      );
      await openSettings(tester);

      await tapSignIn(tester);

      expect(find.byKey(const Key('backup_sign_in_failed')), findsOneWidget);
      expect(
        find.textContaining('missing-id-token'),
        findsOneWidget,
        reason: 'the stage is the only thing that makes this fixable',
      );
      expect(
        find.text('Sign-in failed. Your progress is still on this device.'),
        findsNothing,
        reason: 'the generic message must not replace the real one',
      );
    });

    testWidgets('the user stays on Settings and can retry', (tester) async {
      auth.signInFailure = StateError('network unavailable');
      await openSettings(tester);

      await tapSignIn(tester);

      expect(onSettings(tester), isTrue,
          reason: 'a Settings failure must not evict the user from Settings');
      expect(find.byType(AuthenticationScreen), findsNothing);

      final retry = find.text('Retry');
      expect(retry, findsOneWidget);

      // And the retry works once the cause is gone.
      auth.signInFailure = null;
      migration.guestData = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 2);
      expect(find.byKey(const Key('backup_sign_in_done')), findsOneWidget);
      expect(onSettings(tester), isTrue);
    });

    testWidgets('a retry after a Google cancellation also works', (tester) async {
      auth.signInFailure = const AuthenticationCancelledException();
      migration.guestData = false;
      await openSettings(tester);
      await tapSignIn(tester);
      expect(find.byKey(const Key('backup_sign_in_failed')), findsOneWidget);
      expect(find.textContaining('SHA-1/SHA-256'), findsOneWidget);

      auth.signInFailure = null;
      await tapSignIn(tester);

      expect(auth.signInCalls, 2);
      expect(find.byKey(const Key('backup_sign_in_done')), findsOneWidget);
    });

    testWidgets('a decision backed out of is left open, and says nothing',
        (tester) async {
      await ledger.addRecords([_guestRecord(1)]);
      final container = await openSettings(tester);
      await tapSignIn(tester);
      expect(find.byKey(const Key('guest_decision_merge')), findsOneWidget);

      // Back out of the decision route without choosing.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(container.read(guestUpgradeControllerProvider).awaitingDecision,
          isTrue,
          reason: 'the decision is still owed');
      expect(migration.retireCalls, 0);
      expect(find.byKey(const Key('backup_sign_in_done')), findsNothing);
      expect(find.byKey(const Key('backup_sign_in_failed')), findsNothing);
      expect(find.byKey(const Key('backup_sign_in_cancelled')), findsNothing);
    });
  });

  group('AuthGate stays out of an in-app transition', () {
    /// Boots the app as a stored guest and waits for the workspace.
    Future<ProviderContainer> bootGuest(WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(ProviderScope(
        overrides: overrides(),
        child: const TestApp(home: AuthGate()),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceShell), findsOneWidget);
      return ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceShell)),
      );
    }

    testWidgets('an in-app failure leaves the workspace in place',
        (tester) async {
      auth.signInFailure = StateError('network unavailable');
      final container = await bootGuest(tester);

      await container
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate(origin: GuestUpgradeOrigin.inApp);
      await tester.pumpAndSettle();

      expect(container.read(guestUpgradeControllerProvider).error, isNotNull);
      // The regression: this used to replace the app with startup auth.
      expect(find.byType(AuthenticationScreen), findsNothing);
      expect(find.byType(WorkspaceShell), findsOneWidget);
    });

    testWidgets('an in-app pending decision leaves the workspace in place',
        (tester) async {
      await ledger.addRecords([_guestRecord(1)]);
      final container = await bootGuest(tester);

      await container
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate(origin: GuestUpgradeOrigin.inApp);
      await tester.pumpAndSettle();

      expect(
        container.read(guestUpgradeControllerProvider).awaitingDecision,
        isTrue,
      );
      expect(find.byType(WorkspaceShell), findsOneWidget,
          reason:
              'the decision is resolved above the workspace, not instead of it');
      // Firebase is already authenticated, so isGuestProvider is false; the
      // guest-upgrade barrier is what keeps every ledger read on the guest
      // namespace until the decision is made.
      expect(container.read(guestUpgradePendingProvider), isTrue);
      expect(container.read(activeUserIdProvider), guestUserId,
          reason: 'nothing may read the account ledger before the choice');
    });

    testWidgets('a startup failure still belongs to AuthGate', (tester) async {
      auth.signInFailure = StateError('network unavailable');
      final container = await bootGuest(tester);

      await container
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate();
      await tester.pumpAndSettle();

      expect(
        container.read(guestUpgradeControllerProvider).origin,
        GuestUpgradeOrigin.startup,
      );
      expect(find.byType(AuthenticationScreen), findsOneWidget,
          reason: 'narrowing the gate must not disable the startup path');
    });
  });
}
