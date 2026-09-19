import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';
import 'package:qaza_namaz/domain/services/guest_migration_service.dart';
import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/auth/guest_session.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.account = const AppUser(
      id: 'account-1',
      email: 'account@example.com',
    ),
    AppUser? currentUser,
    this.waitForInitialAuth,
  }) : _current = currentUser;

  final AppUser account;
  final Future<void>? waitForInitialAuth;
  final controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  Object? signInFailure;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (waitForInitialAuth != null) await waitForInitialAuth;
    yield _current;
    yield* controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (signInFailure != null) throw signInFailure!;
    _current = account;
    controller.add(account);
    return account;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    controller.add(null);
  }

  Future<void> dispose() => controller.close();
}

class NoopLocalStore extends QazaLocalStore {
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

class FakeGuestMigrationService extends GuestMigrationService {
  FakeGuestMigrationService({
    required this.guestData,
    this.failMigration = false,
    this.failRetire = false,
  }) : super(
          localStore: NoopLocalStore(),
          remoteRepository: InMemoryQazaRepository(),
        );

  bool guestData;
  bool failMigration;
  bool failRetire;
  int migrateCalls = 0;
  int retireCalls = 0;
  int hasGuestDataCalls = 0;

  @override
  Future<bool> hasGuestData({required String guestUserId}) async {
    hasGuestDataCalls++;
    return guestData;
  }

  @override
  Future<GuestMigrationResult> migrate({
    required String guestUserId,
    required String accountUserId,
    DateTime? completedAt,
  }) async {
    migrateCalls++;
    if (failMigration) throw StateError('simulated migration failure');
    return const GuestMigrationResult(examined: 2, added: 1, completed: 1);
  }

  @override
  Future<void> retireGuestData({required String guestUserId}) async {
    retireCalls++;
    if (failRetire) throw StateError('simulated retirement failure');
    guestData = false;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(ProviderContainer, FakeAuthRepository, FakeGuestMigrationService)>
      makeContainer({
    required bool guestData,
    bool? failMigration,
    bool? failRetire,
    Object? signInFailure,
  }) async {
    final auth = FakeAuthRepository();
    auth.signInFailure = signInFailure;
    final migration = FakeGuestMigrationService(
      guestData: guestData,
      failMigration: failMigration ?? false,
      failRetire: failRetire ?? false,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        guestMigrationServiceProvider.overrideWithValue(migration),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    container.listen(guestSessionProvider, (_, __) {});
    container.listen(guestUpgradePendingProvider, (_, __) {});
    container.listen(guestUpgradeControllerProvider, (_, __) {});

    await container.read(guestSessionProvider.notifier).start();
    await Future<void>.delayed(Duration.zero);
    return (container, auth, migration);
  }

  test(
    'cold-start Google upgrade waits for persisted guest restoration',
    () async {
      SharedPreferences.setMockInitialValues({
        GuestSessionNotifier.storageKey: true,
      });

      final auth = FakeAuthRepository();
      final migration = FakeGuestMigrationService(guestData: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          guestMigrationServiceProvider.overrideWithValue(migration),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      container.listen(guestSessionProvider, (_, __) {});
      container.listen(guestUpgradePendingProvider, (_, __) {});
      container.listen(guestUpgradeControllerProvider, (_, __) {});

      final controller =
          container.read(guestUpgradeControllerProvider.notifier);

      expect(await controller.signInAndMigrate(), isTrue);
      expect(
        container.read(guestUpgradeControllerProvider).pendingAccount?.id,
        auth.account.id,
      );
      expect(container.read(guestSessionProvider), isTrue);
      expect(container.read(activeUserIdProvider), guestUserId);
      expect(migration.migrateCalls, 0);
      expect(migration.retireCalls, 0);
    },
  );

  test(
    'pending decision restoration waits for the initial Firebase auth state',
    () async {
      final authReady = Completer<void>();
      SharedPreferences.setMockInitialValues({
        GuestSessionNotifier.storageKey: true,
        'qaza_guest_upgrade_decision':
            '{"accountId":"account-1"}',
      });

      final auth = FakeAuthRepository(
        currentUser: const AppUser(
          id: 'account-1',
          email: 'account@example.com',
        ),
        waitForInitialAuth: authReady.future,
      );
      final migration = FakeGuestMigrationService(guestData: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          guestMigrationServiceProvider.overrideWithValue(migration),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      container.listen(guestSessionProvider, (_, __) {});
      container.listen(guestUpgradePendingProvider, (_, __) {});
      container.listen(guestUpgradeControllerProvider, (_, __) {});

      final initial = container.read(guestUpgradeControllerProvider);
      expect(initial.restoring, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(guestUpgradeControllerProvider).pendingAccount,
        isNull,
      );

      authReady.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(guestUpgradeControllerProvider).pendingAccount?.id,
        'account-1',
      );
      expect(container.read(guestSessionProvider), isTrue);
      expect(container.read(guestUpgradePendingProvider), isTrue);
      expect(container.read(activeUserIdProvider), guestUserId);
    },
  );

  test(
    'pending guest decision is restored with the guest ledger barrier',
    () async {
      SharedPreferences.setMockInitialValues({
        GuestSessionNotifier.storageKey: true,
        'qaza_guest_upgrade_decision':
            '{"accountId":"account-1"}',
      });

      final auth = FakeAuthRepository(
        currentUser: const AppUser(
          id: 'account-1',
          email: 'account@example.com',
        ),
      );
      final migration = FakeGuestMigrationService(guestData: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          guestMigrationServiceProvider.overrideWithValue(migration),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      container.listen(guestSessionProvider, (_, __) {});
      container.listen(guestUpgradePendingProvider, (_, __) {});
      container.listen(guestUpgradeControllerProvider, (_, __) {});

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(guestUpgradeControllerProvider).pendingAccount?.id,
        'account-1',
      );
      expect(container.read(guestSessionProvider), isTrue);
      expect(container.read(guestUpgradePendingProvider), isTrue);
      expect(container.read(activeUserIdProvider), guestUserId);
    },
  );

  test(
    'Google cancellation keeps guest mode and does not show an auth failure',
    () async {
      final (container, auth, migration) = await makeContainer(
        guestData: true,
        signInFailure: const AuthenticationCancelledException(),
      );
      final controller =
          container.read(guestUpgradeControllerProvider.notifier);

      expect(await controller.signInAndMigrate(), isFalse);
      expect(auth.currentUser, isNull);
      expect(container.read(guestSessionProvider), isTrue);
      expect(container.read(activeUserIdProvider), guestUserId);
      expect(container.read(guestUpgradePendingProvider), isFalse);
      expect(
        container.read(guestUpgradeControllerProvider).error,
        isNull,
      );
      expect(migration.migrateCalls, 0);
      expect(migration.retireCalls, 0);
    },
  );

  test('guest sign-in with empty ledger ends guest mode without migration',
      () async {
    final (container, auth, migration) = await makeContainer(guestData: false);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    expect(await controller.signInAndMigrate(), isTrue);
    expect(migration.migrateCalls, 0);
    expect(migration.retireCalls, 0);
    expect(auth.currentUser, isNotNull);
    expect(container.read(isGuestProvider), isFalse);
    expect(container.read(activeUserIdProvider), auth.account.id);
  });

  test('guest Google authentication failure keeps guest mode and diagnostic',
      () async {
    final (container, auth, migration) = await makeContainer(
      guestData: true,
      signInFailure: StateError('firebase-auth/operation-not-allowed'),
    );
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    expect(await controller.signInAndMigrate(), isFalse);
    expect(auth.currentUser, isNull);
    expect(migration.migrateCalls, 0);
    expect(container.read(guestSessionProvider), isTrue);
    expect(container.read(activeUserIdProvider), guestUserId);
    expect(
      container.read(guestUpgradeControllerProvider).error,
      contains('firebase-auth/operation-not-allowed'),
    );
  });

  test('guest sign-in with data pauses on an explicit choice and stays guest',
      () async {
    final (container, auth, migration) = await makeContainer(guestData: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    expect(await controller.signInAndMigrate(), isTrue);
    await container.read(authStateProvider.future);

    final state = container.read(guestUpgradeControllerProvider);
    expect(state.pendingAccount?.id, auth.account.id);
    expect(migration.hasGuestDataCalls, 1);
    expect(migration.migrateCalls, 0);
    expect(migration.retireCalls, 0);
    expect(container.read(activeUserIdProvider), guestUserId);
    expect(container.read(isGuestProvider), isFalse);
  });

  test('Merge Data migrates then retires guest data', () async {
    final (container, auth, migration) = await makeContainer(guestData: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    await controller.signInAndMigrate();
    expect(await controller.mergeData(), isTrue);

    expect(migration.migrateCalls, 1);
    expect(migration.retireCalls, 1);
    expect(container.read(guestSessionProvider), isFalse);
    expect(container.read(guestUpgradePendingProvider), isFalse);
    expect(container.read(activeUserIdProvider), auth.account.id);
  });

  test('Use Account Data retires guest data without migration', () async {
    final (container, auth, migration) = await makeContainer(guestData: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    await controller.signInAndMigrate();
    expect(await controller.useAccountData(), isTrue);

    expect(migration.migrateCalls, 0);
    expect(migration.retireCalls, 1);
    expect(container.read(guestSessionProvider), isFalse);
    expect(container.read(activeUserIdProvider), auth.account.id);
  });

  test('Cancel signs out and keeps guest records untouched', () async {
    final (container, auth, migration) = await makeContainer(guestData: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    await controller.signInAndMigrate();
    expect(await controller.cancelAndKeepGuest(), isTrue);

    expect(auth.currentUser, isNull);
    expect(migration.migrateCalls, 0);
    expect(migration.retireCalls, 0);
    expect(migration.guestData, isTrue);
    expect(container.read(guestSessionProvider), isTrue);
    expect(container.read(activeUserIdProvider), guestUserId);
    expect(container.read(guestUpgradePendingProvider), isFalse);
  });

  test('migration failure leaves guest data and decision active for retry',
      () async {
    final (container, _, migration) =
        await makeContainer(guestData: true, failMigration: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    await controller.signInAndMigrate();
    expect(await controller.mergeData(), isFalse);
    expect(migration.retireCalls, 0);
    expect(migration.guestData, isTrue);
    expect(container.read(guestUpgradeControllerProvider).pendingAccount,
        isNotNull);

    migration.failMigration = false;
    expect(await controller.mergeData(), isTrue);
    expect(migration.migrateCalls, 2);
    expect(migration.retireCalls, 1);
    expect(migration.guestData, isFalse);
  });

  testWidgets('pending guest upgrade shows all three explicit choices',
      (tester) async {
    final (container, _, migration) = await makeContainer(guestData: true);

    await container
        .read(guestUpgradeControllerProvider.notifier)
        .signInAndMigrate();

    expect(
      container.read(guestUpgradeControllerProvider).pendingAccount,
      isNotNull,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(home: AuthenticationScreen()),
      ),
    );
    // The authentication screen can schedule its provider restoration on the first frame.
    // Advance a bounded amount of fake time instead of settling indefinitely.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Guest progress found'), findsOneWidget);
    expect(find.text('Merge Data'), findsOneWidget);
    expect(find.text('Use Account Data'), findsOneWidget);
    expect(find.text('Keep Guest Data / Cancel Sign-In'), findsOneWidget);
    expect(migration.migrateCalls, 0);
  });

  test('retirement failure does not end the guest session', () async {
    final (container, _, migration) =
        await makeContainer(guestData: true, failRetire: true);
    final controller = container.read(guestUpgradeControllerProvider.notifier);

    await controller.signInAndMigrate();
    expect(await controller.mergeData(), isFalse);

    expect(migration.migrateCalls, 1);
    expect(migration.retireCalls, 1);
    expect(container.read(guestSessionProvider), isTrue);
    expect(container.read(guestUpgradePendingProvider), isTrue);
    expect(container.read(guestUpgradeControllerProvider).pendingAccount,
        isNotNull);
  });
}
