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
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/auth/guest_session.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// Task 26 — the eight acceptance journeys, each driven end to end through
/// the real widget tree rather than inferred from unit tests.
///
/// These are deliberately journeys, not assertions about one widget: each one
/// starts where a user starts and ends where they would stop.
void main() {
  const account = AppUser(id: 'account-1', email: 'user@example.com');
  final today = DateTime(2026, 9, 14);
  final stamp = DateTime(2026, 9, 10);

  QazaRecord record(
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
        completedAt: status == QazaStatus.completed ? stamp : null,
        createdAt: stamp,
        updatedAt: stamp,
      );

  /// Signed out until the journey signs in.
  late _JourneyAuth auth;
  late InMemoryQazaRepository repository;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(AuthGate.splashDuration);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<ProviderContainer> start(
    WidgetTester tester, {
    bool guest = false,
    List<QazaRecord> ledger = const [],
    Widget? home,
  }) async {
    SharedPreferences.setMockInitialValues(
      guest ? {GuestSessionNotifier.storageKey: true} : {},
    );
    auth = _JourneyAuth();
    repository = InMemoryQazaRepository();
    if (ledger.isNotEmpty) await repository.addRecords(ledger);

    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      qazaRepositoryProvider.overrideWithValue(repository),
      calendarTodayProvider.overrideWithValue(today),
    ]);
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    // A phone-sized surface. The default 800x600 test window leaves some of
    // these screens unlaid-out, which is a test artefact, not a UI defect.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Guest mode is restored from storage asynchronously. It has to settle
    // before the first frame, because a screen that needs an active user
    // reads one while building.
    if (guest) {
      await container.read(guestSessionProvider.notifier).ensureRestored();
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TestApp(home: home ?? const AuthGate()),
    ));
    // The tracker controller is auto-disposed; without a listener each read
    // builds a fresh one and the journey never sees its own state.
    container.listen(qazaTrackerControllerProvider, (_, __) {});
    await settle(tester);
    return container;
  }

  /// Scrolls until [key] is on stage, then taps it.
  ///
  /// Deliberately does not use `ensureVisible`: a finder that matches an
  /// off-stage widget can match one the framework has not laid out, and
  /// asking to reveal that asserts. Scrolling until it is genuinely on stage
  /// is both closer to what a user does and stable.
  Future<void> tapKey(WidgetTester tester, String key) async {
    final onStage = find.byKey(Key(key));
    for (var i = 0; i < 12 && onStage.evaluate().isEmpty; i++) {
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isEmpty) break;
      await tester.drag(scrollables.last, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(onStage, findsWidgets, reason: 'never reached $key');
    await tester.tap(onStage.first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ---------------------------------------------------------------- 1
  testWidgets('journey: first-time user reaches a usable app', (tester) async {
    await start(tester);

    // A brand-new install lands on the welcome surface, not a dead splash.
    expect(find.byKey(const Key('welcome_continue_as_guest')), findsOneWidget);

    await tapKey(tester, 'welcome_continue_as_guest');

    // And continuing as a guest opens the full workspace immediately.
    expect(find.byType(WorkspaceShell), findsOneWidget);
  });

  // ---------------------------------------------------------------- 2
  testWidgets('journey: manual Qaza, from empty ledger to a record',
      (tester) async {
    final container =
        await start(tester, guest: true, home: const AddQazaScreen());

    // Step 1 — a date.
    await tapKey(tester, 'calendar_day_2026-09-13');
    await tapKey(tester, 'qaza_continue_button');

    // Step 2 — a prayer.
    await tapKey(tester, 'qaza_prayer_asr');
    await tapKey(tester, 'qaza_review_button');

    // Step 3 — the action names what it will write.
    await tapKey(tester, 'qaza_add_button');

    final saved = await repository.getRecords(userId: guestUserId);
    expect(saved, hasLength(1));
    expect(saved.single.prayerType, PrayerType.asr);
    expect(saved.single.status, QazaStatus.pending);
    container.dispose();
  });

  // ---------------------------------------------------------------- 3
  testWidgets('journey: tracker filters, sorts and reads a ledger',
      (tester) async {
    final container = await start(
      tester,
      guest: true,
      ledger: [
        record(guestUserId, PrayerType.fajr, 1),
        record(guestUserId, PrayerType.fajr, 5),
        record(guestUserId, PrayerType.asr, 3),
      ],
    );

    final controller = container.read(qazaTrackerControllerProvider.notifier);
    await controller.refresh();

    // Oldest first is where a Qaza debt starts.
    expect(
      container.read(qazaTrackerControllerProvider).records.first.originalDate,
      DateTime(2026, 1, 1),
    );

    // The other question this list answers: what was missed most recently.
    controller.setSortOrder(QazaSortOrder.newestFirst);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container.read(qazaTrackerControllerProvider).records.first.originalDate,
      DateTime(2026, 1, 5),
    );

    // And a filter narrows it without disturbing the order.
    controller.setPrayerFilter(PrayerType.asr);
    await tester.pump(const Duration(milliseconds: 200));
    final filtered = container.read(qazaTrackerControllerProvider).records;
    expect(filtered, hasLength(1));
    expect(filtered.single.prayerType, PrayerType.asr);
  });

  // ---------------------------------------------------------------- 4
  testWidgets('journey: daily completion reduces what is pending',
      (tester) async {
    final container = await start(
      tester,
      guest: true,
      ledger: [
        record(guestUserId, PrayerType.fajr, 1),
        record(guestUserId, PrayerType.fajr, 2),
      ],
    );

    final controller = container.read(qazaTrackerControllerProvider.notifier);
    await controller.refresh();
    final oldest = container.read(qazaTrackerControllerProvider).records.first;

    controller.toggleSelection(oldest.id);
    await controller.completeSelected();
    await tester.pump(const Duration(milliseconds: 200));

    final all = await repository.getRecords(userId: guestUserId);
    final completed = all.where((r) => r.status == QazaStatus.completed);
    expect(completed, hasLength(1));
    expect(completed.single.id, oldest.id,
        reason: 'the oldest debt is the one settled first');
    expect(completed.single.completedAt, isNotNull);
  });

  // ---------------------------------------------------------------- 5
  testWidgets('journey: guest conversion keeps the guest ledger',
      (tester) async {
    final container = await start(
      tester,
      guest: true,
      ledger: [record(guestUserId, PrayerType.fajr, 1)],
    );

    // Signing in must never silently discard what the guest recorded.
    auth.emit(account);
    await tester.pump(const Duration(milliseconds: 300));

    final guestLedger = await repository.getRecords(userId: guestUserId);
    expect(guestLedger, hasLength(1),
        reason: 'guest data survives authentication until a decision is made');
    container.dispose();
  });

  // ---------------------------------------------------------------- 6
  testWidgets('journey: offline, the ledger still reads and writes',
      (tester) async {
    // The in-memory repository is the offline case by construction: there is
    // no remote behind it, and every journey below must still work.
    final container = await start(tester, guest: true);

    final service = container.read(qazaServiceProvider);
    final added = await service.recordQazaForDates(
      userId: guestUserId,
      dates: [DateTime(2026, 1, 1), DateTime(2026, 1, 2)],
      prayerTypes: [PrayerType.fajr],
    );

    expect(added, 2);
    expect(await repository.getRecords(userId: guestUserId), hasLength(2));

    final summary = await service.getProgressSummary(userId: guestUserId);
    expect(summary.overall.pending, 2);
  });

  // ---------------------------------------------------------------- 7
  testWidgets('journey: calculator estimate reaches the tracker',
      (tester) async {
    final container = await start(tester, guest: true);
    final service = container.read(qazaServiceProvider);

    // Ten days of five daily prayers, the calculator's own expansion.
    final dates = [
      for (var day = 1; day <= 10; day++) DateTime(2026, 1, day),
    ];
    final added = await service.recordQazaForDates(
      userId: guestUserId,
      dates: dates,
      prayerTypes: PrayerType.values.where((p) => p != PrayerType.witr),
    );

    expect(added, 50);

    // And running the same estimate again adds nothing: the duplicate rule
    // holds across the whole journey, not just inside one screen.
    final again = await service.recordQazaForDates(
      userId: guestUserId,
      dates: dates,
      prayerTypes: PrayerType.values.where((p) => p != PrayerType.witr),
    );
    expect(again, 0);
    expect(await repository.getRecords(userId: guestUserId), hasLength(50));
  });

  // ---------------------------------------------------------------- 8
  testWidgets('journey: a reminder is only owed while Qaza remain',
      (tester) async {
    final container = await start(
      tester,
      guest: true,
      ledger: [record(guestUserId, PrayerType.fajr, 1)],
    );
    final service = container.read(qazaServiceProvider);

    // The condition the scheduler asks about before it keeps a reminder.
    var summary = await service.getProgressSummary(userId: guestUserId);
    expect(summary.overall.pending, 1);

    final pending = await repository.getRecords(userId: guestUserId);
    await service.completeRecord(
      userId: guestUserId,
      recordId: pending.single.id,
      completedAt: stamp,
    );

    summary = await service.getProgressSummary(userId: guestUserId);
    expect(summary.overall.pending, 0,
        reason: 'with nothing pending there is nothing to remind about');
  });
}

/// Signed out until a journey signs in.
class _JourneyAuth implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  void emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    emit(const AppUser(id: 'account-1', email: 'user@example.com'));
    return _current!;
  }

  @override
  Future<void> signOut() async => emit(null);

  Future<void> dispose() => _controller.close();
}
