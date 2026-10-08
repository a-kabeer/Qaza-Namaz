import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';

void main() {
  QazaProgressSummary summaryFor(Map<PrayerType, int> pending) {
    final byPrayer = <PrayerType, PrayerProgress>{
      for (final prayer in PrayerType.values)
        prayer: PrayerProgress(
          prayerType: prayer,
          progress: QazaProgress(
            pending: pending[prayer] ?? 0,
            completed: 0,
          ),
        ),
    };
    final totalPending = byPrayer.values.fold<int>(
      0,
      (sum, item) => sum + item.progress.pending,
    );
    return QazaProgressSummary(
      overall: QazaProgress(pending: totalPending, completed: 0),
      byPrayer: byPrayer,
    );
  }

  Future<HomeSelectedPrayerState> resolve({
    required HomePrayerSelectionMode mode,
    required PrayerType? currentPrayer,
    required Map<PrayerType, int> pending,
    required bool witrEnabled,
    PrayerType cursor = PrayerType.fajr,
    PrayerType selectedPrayer = PrayerType.fajr,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    await database.customInsert(
      '''INSERT INTO meta_store (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString('qaza_home_completion_mode'),
        Variable.withString(mode.name),
      ],
    );
    await database.customInsert(
      '''INSERT INTO meta_store (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString('qaza_home_auto_sequence_prayer'),
        Variable.withString(cursor.name),
      ],
    );
    await database.customInsert(
      '''INSERT INTO meta_store (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString('qaza_home_selected_prayer'),
        Variable.withString(selectedPrayer.name),
      ],
    );
    addTearDown(database.close);

    final summary = summaryFor(pending);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        progressSummaryProvider.overrideWith((ref) => Future.value(summary)),
        currentQazaPrayerTypeProvider.overrideWith(
          (ref) => currentPrayer,
        ),
        effectiveWitrProvider.overrideWith((ref) => witrEnabled),
      ],
    );
    addTearDown(container.dispose);
    final progressSubscription = container.listen(
      progressSummaryProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(progressSubscription.close);

    container.read(homePrayerSelectionProvider);
    await container.read(progressSummaryProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    return container.read(homeSelectedPrayerProvider);
  }

  group('homeSelectedPrayerProvider pending-aware target resolution', () {
    test('Auto Sequence keeps the legacy cursor non-authoritative', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.autoSequence,
        cursor: PrayerType.isha,
        currentPrayer: PrayerType.isha,
        pending: {
          PrayerType.fajr: 10,
          PrayerType.isha: 0,
          PrayerType.witr: 0,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.isha);
      expect(selected.source, HomePrayerSelectionSource.autoSequence);
    });

    test('Auto Sequence does not resolve a later prayer type from pending counts', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.autoSequence,
        cursor: PrayerType.zuhr,
        currentPrayer: PrayerType.zuhr,
        pending: {
          PrayerType.zuhr: 0,
          PrayerType.asr: 0,
          PrayerType.maghrib: 10,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.zuhr);
    });

    test('Auto Sequence does not select by prayer-type availability', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.autoSequence,
        cursor: PrayerType.fajr,
        currentPrayer: PrayerType.fajr,
        pending: {
          PrayerType.asr: 360,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.fajr);
    });

    test('Persisted Auto Sequence cursor is not used to choose a pending record', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.autoSequence,
        cursor: PrayerType.isha,
        currentPrayer: PrayerType.isha,
        pending: {
          PrayerType.fajr: 10,
          PrayerType.isha: 0,
          PrayerType.witr: 0,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.isha);
    });

    test('Prayer Time keeps current prayer when pending', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.isha,
        pending: {
          PrayerType.isha: 10,
          PrayerType.fajr: 10,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.isha);
      expect(selected.source, HomePrayerSelectionSource.prayerTime);
    });

    test('Prayer Time falls back from zero-pending Asr to Maghrib', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.asr,
        pending: {
          PrayerType.asr: 0,
          PrayerType.maghrib: 10,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.maghrib);
      expect(selected.source, HomePrayerSelectionSource.prayerTime);
    });

    test('Prayer Time falls back from Isha and zero-pending Witr to Fajr', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.isha,
        pending: {
          PrayerType.fajr: 10,
          PrayerType.isha: 0,
          PrayerType.witr: 0,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.fajr);
    });

    test('Prayer Time skips multiple zero-pending prayers before a later pending prayer', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.isha,
        pending: {
          PrayerType.isha: 0,
          PrayerType.witr: 0,
          PrayerType.fajr: 0,
          PrayerType.zuhr: 10,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.zuhr);
    });

    test('Witr disabled is never actionable in either mode', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.witr,
        pending: {
          PrayerType.witr: 10,
          PrayerType.fajr: 10,
        },
        witrEnabled: false,
      );

      expect(selected.prayer, PrayerType.fajr);
    });

    test('enabled Witr with pending Qaza is selectable', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.witr,
        pending: {
          PrayerType.witr: 10,
        },
        witrEnabled: true,
      );

      expect(selected.prayer, PrayerType.witr);
    });

    test('all zero pending produces no actionable target', () async {
      final selected = await resolve(
        mode: HomePrayerSelectionMode.prayerTime,
        currentPrayer: PrayerType.isha,
        pending: const <PrayerType, int>{},
        witrEnabled: true,
      );

      expect(selected.prayer, isNull);
      expect(selected.source, HomePrayerSelectionSource.unavailable);
    });

    test(
      'Prayer Selection remains sticky and is not changed by pending fallback',
      () async {
        final selected = await resolve(
          mode: HomePrayerSelectionMode.prayerSelection,
          currentPrayer: PrayerType.asr,
          selectedPrayer: PrayerType.isha,
          pending: {
            PrayerType.fajr: 10,
            PrayerType.isha: 10,
          },
          witrEnabled: true,
        );

        expect(selected.prayer, PrayerType.isha);
        expect(selected.source, HomePrayerSelectionSource.prayerSelection);
      },
    );
  });
}
