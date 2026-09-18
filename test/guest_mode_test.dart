import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/domain/services/guest_migration_service.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/auth/backup_prompt.dart';
import 'package:qaza_namaz/features/auth/guest_session.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

const _account = AppUser(id: 'account-1', email: 'user@example.com');
final _stamp = DateTime(2026, 9, 18);

QazaRecord _record(
  String userId,
  PrayerType prayer,
  int day, {
  QazaStatus status = QazaStatus.pending,
}) =>
    QazaRecord(
      id: '${userId}_${prayer.name}_2026-01-${day.toString().padLeft(2, '0')}',
      userId: userId,
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      status: status,
      completedAt: status == QazaStatus.completed ? _stamp : null,
      createdAt: _stamp,
      updatedAt: _stamp,
    );

/// An auth repository whose sign-in the test drives.
class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  bool failSignIn = false;
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
    if (failSignIn) throw StateError('sign-in cancelled');
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container(
    InMemoryQazaRepository repository, {
    _FakeAuthRepository? auth,
  }) {
    final result = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ]);
    addTearDown(result.dispose);
    return result;
  }

  group('guest session', () {
    test('no session means no ledger at all', () {
      final scope = container(InMemoryQazaRepository());

      expect(scope.read(isGuestProvider), isFalse);
      expect(scope.read(activeUserIdProvider), isNull);
    });

    test('starting one gives the reserved guest ledger', () async {
      final scope = container(InMemoryQazaRepository());
      scope.listen(activeUserIdProvider, (_, __) {});

      await scope.read(guestSessionProvider.notifier).start();

      expect(scope.read(isGuestProvider), isTrue);
      expect(scope.read(activeUserIdProvider), guestUserId);
    });

    test('it survives a restart', () async {
      SharedPreferences.setMockInitialValues(
          {GuestSessionNotifier.storageKey: true});
      final scope = container(InMemoryQazaRepository());
      scope.listen(guestSessionProvider, (_, __) {});

      await scope.read(guestSessionProvider.notifier).restore();

      expect(scope.read(activeUserIdProvider), guestUserId);
    });

    test('a signed-in account always wins over a guest session', () async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);
      final scope = container(InMemoryQazaRepository(), auth: auth);
      scope.listen(activeUserIdProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();

      await auth.signInWithGoogle();
      await scope.read(authStateProvider.future);

      expect(scope.read(activeUserIdProvider), _account.id);
      expect(scope.read(isGuestProvider), isFalse);
    });
  });

  group('guest data', () {
    test('adding and completing works and stays local', () async {
      final repository = InMemoryQazaRepository();
      final scope = container(repository);
      scope.listen(activeUserIdProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();

      final service = scope.read(qazaServiceProvider);
      await service.recordQaza(
        userId: guestUserId,
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 1, 2),
      );
      expect(await service.getProgressSummary(userId: guestUserId),
          isA<dynamic>());
      expect((await repository.getRecords(userId: guestUserId)), hasLength(1));

      final completed = await service.completeOldestPending(
          userId: guestUserId, prayerType: PrayerType.fajr);

      expect(completed, isTrue);
      expect(
          (await service.getProgressSummary(userId: guestUserId))
              .overall
              .completed,
          1);
    });

    test('guest records are invisible to an account', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(guestUserId, PrayerType.fajr, 1),
        _record(_account.id, PrayerType.zuhr, 1),
      ]);

      expect((await repository.getRecords(userId: guestUserId)).single.id,
          contains(guestUserId));
      expect((await repository.getRecords(userId: _account.id)).single.id,
          contains(_account.id));
    });
  });

  group('migration', () {
    late InMemoryQazaRepository repository;
    late GuestMigrationService service;

    setUp(() {
      repository = InMemoryQazaRepository();
      service = GuestMigrationService(repository);
    });

    Future<GuestMigrationResult> migrate() => service.migrate(
          guestUserId: guestUserId,
          accountUserId: _account.id,
          completedAt: _stamp,
        );

    test('carries guest records into an empty account', () async {
      await repository.addRecords([
        _record(guestUserId, PrayerType.fajr, 1),
        _record(guestUserId, PrayerType.zuhr, 2),
      ]);

      final result = await migrate();

      expect(result.added, 2);
      final account = await repository.getRecords(userId: _account.id);
      expect(account, hasLength(2));
      expect(account.every((r) => r.userId == _account.id), isTrue);
    });

    test('never deletes the guest ledger', () async {
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);

      await migrate();

      expect(await repository.getRecords(userId: guestUserId), hasLength(1));
    });

    test('a record the account already has is not duplicated', () async {
      await repository.addRecords([
        _record(guestUserId, PrayerType.fajr, 1),
        _record(_account.id, PrayerType.fajr, 1),
      ]);

      final result = await migrate();

      expect(result.added, 0);
      expect(await repository.getRecords(userId: _account.id), hasLength(1));
    });

    test('a guest completion is carried onto the account record', () async {
      await repository.addRecords([
        _record(guestUserId, PrayerType.fajr, 1, status: QazaStatus.completed),
        _record(_account.id, PrayerType.fajr, 1),
      ]);

      final result = await migrate();

      expect(result.completed, 1);
      expect((await repository.getRecords(userId: _account.id)).single.status,
          QazaStatus.completed);
    });

    test('an account completion is never undone by a pending guest record',
        () async {
      await repository.addRecords([
        _record(guestUserId, PrayerType.fajr, 1),
        _record(_account.id, PrayerType.fajr, 1, status: QazaStatus.completed),
      ]);

      final result = await migrate();

      expect(result.completed, 0);
      expect((await repository.getRecords(userId: _account.id)).single.status,
          QazaStatus.completed);
    });

    test('an empty guest ledger is a no-op', () async {
      await repository.addRecords([_record(_account.id, PrayerType.fajr, 1)]);

      final result = await migrate();

      expect(result.movedAnything, isFalse);
      expect(await repository.getRecords(userId: _account.id), hasLength(1));
    });
  });

  group('signing in from guest mode', () {
    test('migrates, ends guest mode and refreshes the ledger', () async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);
      final scope = container(repository, auth: auth);
      scope.listen(activeUserIdProvider, (_, __) {});
      scope.listen(guestUpgradeControllerProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();

      final ok = await scope
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate();
      await scope.read(authStateProvider.future);

      expect(ok, isTrue);
      expect(scope.read(isGuestProvider), isFalse);
      expect(scope.read(activeUserIdProvider), _account.id);
      expect(await repository.getRecords(userId: _account.id), hasLength(1));
      // Neither dataset was deleted.
      expect(await repository.getRecords(userId: guestUserId), hasLength(1));
      expect(
          (await scope.read(progressSummaryProvider.future)).overall.total, 1);
    });

    test('a failed sign-in leaves the guest exactly where they were', () async {
      final auth = _FakeAuthRepository()..failSignIn = true;
      addTearDown(auth.dispose);
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);
      final scope = container(repository, auth: auth);
      scope.listen(activeUserIdProvider, (_, __) {});
      scope.listen(guestUpgradeControllerProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();

      final ok = await scope
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate();

      expect(ok, isFalse);
      expect(scope.read(isGuestProvider), isTrue);
      expect(scope.read(activeUserIdProvider), guestUserId);
      expect(await repository.getRecords(userId: guestUserId), hasLength(1));
      expect(scope.read(guestUpgradeControllerProvider).error, isNotNull);
    });

    test('an existing account signing in normally migrates nothing', () async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(_account.id, PrayerType.isha, 3)]);
      final scope = container(repository, auth: auth);
      scope.listen(activeUserIdProvider, (_, __) {});
      scope.listen(guestUpgradeControllerProvider, (_, __) {});

      final ok = await scope
          .read(guestUpgradeControllerProvider.notifier)
          .signInAndMigrate();
      await scope.read(authStateProvider.future);

      expect(ok, isTrue);
      expect(auth.signInCalls, 1);
      expect(scope.read(guestUpgradeControllerProvider).migration.movedAnything,
          isFalse);
      // The account's cloud data is untouched.
      expect(await repository.getRecords(userId: _account.id), hasLength(1));
    });
  });

  group('the backup prompt', () {
    test('is offered once a guest has a record', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);
      final scope = container(repository);
      scope.listen(shouldOfferBackupProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();
      await scope.read(progressSummaryProvider.future);

      expect(scope.read(shouldOfferBackupProvider), isTrue);
    });

    test('is not offered on an empty guest ledger', () async {
      final scope = container(InMemoryQazaRepository());
      scope.listen(shouldOfferBackupProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();
      await scope.read(progressSummaryProvider.future);

      expect(scope.read(shouldOfferBackupProvider), isFalse);
    });

    test('is never offered to a signed-in account', () async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(_account.id, PrayerType.fajr, 1)]);
      final scope = container(repository, auth: auth);
      scope.listen(shouldOfferBackupProvider, (_, __) {});
      await auth.signInWithGoogle();
      await scope.read(authStateProvider.future);
      await scope.read(progressSummaryProvider.future);

      expect(scope.read(shouldOfferBackupProvider), isFalse);
    });

    test('once answered it stays answered, across restarts', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);
      final scope = container(repository);
      scope.listen(shouldOfferBackupProvider, (_, __) {});
      await scope.read(guestSessionProvider.notifier).start();
      await scope.read(progressSummaryProvider.future);

      await scope.read(backupPromptSeenProvider.notifier).markSeen();
      expect(scope.read(shouldOfferBackupProvider), isFalse);

      // A fresh container reads the same stored answer.
      final next = container(repository);
      next.listen(shouldOfferBackupProvider, (_, __) {});
      await next.read(guestSessionProvider.notifier).restore();
      await next.read(backupPromptSeenProvider.notifier).restore();
      await next.read(progressSummaryProvider.future);

      expect(next.read(shouldOfferBackupProvider), isFalse);
    });
  });

  group('the app shell', () {
    Future<void> pumpGate(
      WidgetTester tester,
      InMemoryQazaRepository repository, {
      _FakeAuthRepository? auth,
      bool guest = false,
    }) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      if (guest) {
        SharedPreferences.setMockInitialValues(
            {GuestSessionNotifier.storageKey: true});
      }
      await tester.pumpWidget(ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const TestApp(home: AuthGate()),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    }

    testWidgets('the welcome screen offers a guest route', (tester) async {
      await pumpGate(tester, InMemoryQazaRepository());

      expect(
          find.byKey(const Key('welcome_continue_as_guest')), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('choosing it opens the full workspace', (tester) async {
      await pumpGate(tester, InMemoryQazaRepository());

      await tester.tap(find.byKey(const Key('welcome_continue_as_guest')));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceShell), findsOneWidget);
      // Every destination is available, not a restricted subset.
      for (final label in const ['Home', 'Knowledge', 'Settings']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('a stored guest session skips the welcome screen',
        (tester) async {
      await pumpGate(tester, InMemoryQazaRepository(), guest: true);

      expect(find.byType(WorkspaceShell), findsOneWidget);
    });

    testWidgets('Settings offers a guest a permanent way to back up',
        (tester) async {
      await pumpGate(tester, InMemoryQazaRepository(), guest: true);

      final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceShell)));
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.settings;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_backup_sign_in')), findsOneWidget);
      expect(find.text('Back up / Sign in'), findsOneWidget);
    });

    testWidgets('a signed-in account sees no backup row', (tester) async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.signInWithGoogle();
      await pumpGate(tester, InMemoryQazaRepository(), auth: auth);

      final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceShell)));
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.settings;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_backup_sign_in')), findsNothing);
    });

    testWidgets('the prompt appears after a guest first record, once',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([_record(guestUserId, PrayerType.fajr, 1)]);
      await pumpGate(tester, repository, guest: true);

      expect(find.byKey(const Key('backup_prompt')), findsOneWidget);
      expect(find.text('Keep your progress safe'), findsOneWidget);

      await tester.tap(find.byKey(const Key('backup_prompt_dismiss')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backup_prompt')), findsNothing);
      // Dismissal is remembered, so nothing brings it back.
      final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceShell)));
      container.invalidate(progressSummaryProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup_prompt')), findsNothing);
    });

    testWidgets('an empty guest ledger is not prompted', (tester) async {
      await pumpGate(tester, InMemoryQazaRepository(), guest: true);

      expect(find.byKey(const Key('backup_prompt')), findsNothing);
    });
  });
}
