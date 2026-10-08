import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/services/qaza_targeting_service.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

void main() {
  const service = QazaTargetingService();

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

  group('QazaTargetingService', () {
    test('normal canonical sequence resolves the starting prayer when pending',
        () {
      final summary = summaryFor({
        for (final prayer in PrayerTypeX.qazaSequence) prayer: 1,
      });

      for (final prayer in PrayerTypeX.qazaSequence) {
        expect(
          service.resolveNextPendingPrayer(
            summary: summary,
            startPrayer: prayer,
            witrEnabled: true,
          ),
          prayer,
        );
      }
    });

    test('skips zero-pending Witr and wraps to Fajr', () {
      final summary = summaryFor({
        PrayerType.fajr: 10,
        PrayerType.isha: 10,
        PrayerType.witr: 0,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.witr,
          witrEnabled: true,
        ),
        PrayerType.fajr,
      );
    });

    test('skips zero-pending Maghrib', () {
      final summary = summaryFor({
        PrayerType.isha: 10,
        PrayerType.maghrib: 0,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.maghrib,
          witrEnabled: true,
        ),
        PrayerType.isha,
      );
    });

    test('skips a zero-pending middle prayer', () {
      final summary = summaryFor({
        PrayerType.asr: 10,
        PrayerType.maghrib: 0,
        PrayerType.isha: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.maghrib,
          witrEnabled: true,
        ),
        PrayerType.isha,
      );
    });

    test('skips multiple consecutive zero-pending prayers', () {
      final summary = summaryFor({
        PrayerType.fajr: 10,
        PrayerType.zuhr: 0,
        PrayerType.asr: 0,
        PrayerType.maghrib: 0,
        PrayerType.isha: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.zuhr,
          witrEnabled: true,
        ),
        PrayerType.isha,
      );
    });

    test('wraps from Isha through zero-pending Witr to Fajr', () {
      final summary = summaryFor({
        PrayerType.fajr: 10,
        PrayerType.isha: 0,
        PrayerType.witr: 0,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.fajr,
      );
    });

    test('selects the only pending prayer even when it is in the middle', () {
      final summary = summaryFor({
        PrayerType.asr: 360,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.fajr,
          witrEnabled: true,
        ),
        PrayerType.asr,
      );
    });

    test('Witr disabled is skipped even when it has pending Qaza', () {
      final summary = summaryFor({
        PrayerType.fajr: 10,
        PrayerType.witr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.witr,
          witrEnabled: false,
        ),
        PrayerType.fajr,
      );
    });

    test('enabled Witr with pending Qaza is selectable', () {
      final summary = summaryFor({
        PrayerType.witr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.witr,
      );
    });

    test('returns null when every prayer has zero pending', () {
      final summary = summaryFor(const <PrayerType, int>{});

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.fajr,
          witrEnabled: true,
        ),
        isNull,
      );
    });

    test('re-evaluates the latest pending counts instead of caching a target',
        () {
      final first = summaryFor({
        PrayerType.fajr: 10,
      });
      final second = summaryFor({
        PrayerType.asr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: first,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.fajr,
      );
      expect(
        service.resolveNextPendingPrayer(
          summary: second,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.asr,
      );
    });

    test(
        'persisted Auto Sequence cursor is still dynamically resolved past zero pending',
        () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customInsert(
        '''INSERT INTO meta_store (key, value) VALUES (?, ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        variables: [
          Variable.withString('qaza_home_completion_mode'),
          Variable.withString(HomePrayerSelectionMode.autoSequence.name),
        ],
      );
      await database.customInsert(
        '''INSERT INTO meta_store (key, value) VALUES (?, ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        variables: [
          Variable.withString('qaza_home_auto_sequence_prayer'),
          Variable.withString(PrayerType.isha.name),
        ],
      );

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      container.read(homePrayerSelectionProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final state = container.read(homePrayerSelectionProvider);
      expect(state.autoSequencePrayer, PrayerType.isha);

      final summary = summaryFor({
        PrayerType.fajr: 10,
        PrayerType.isha: 0,
        PrayerType.witr: 0,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: state.autoSequencePrayer,
          witrEnabled: true,
        ),
        PrayerType.fajr,
      );
    });

    test('Prayer Time keeps current prayer when it has pending Qaza', () {
      final summary = summaryFor({
        PrayerType.isha: 10,
        PrayerType.fajr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.isha,
      );
    });

    test('Prayer Time falls back from zero-pending Asr to Maghrib', () {
      final summary = summaryFor({
        PrayerType.asr: 0,
        PrayerType.maghrib: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.asr,
          witrEnabled: true,
        ),
        PrayerType.maghrib,
      );
    });

    test('Prayer Time falls back from zero-pending Isha and Witr to Fajr', () {
      final summary = summaryFor({
        PrayerType.isha: 0,
        PrayerType.witr: 0,
        PrayerType.fajr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.fajr,
      );
    });

    test(
        'Prayer Time skips several zero-pending prayers before the next available prayer',
        () {
      final summary = summaryFor({
        PrayerType.isha: 0,
        PrayerType.witr: 0,
        PrayerType.fajr: 0,
        PrayerType.zuhr: 10,
      });

      expect(
        service.resolveNextPendingPrayer(
          summary: summary,
          startPrayer: PrayerType.isha,
          witrEnabled: true,
        ),
        PrayerType.zuhr,
      );
    });

    test('Prayer Selection remains outside pending-aware fallback', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: PrayerType.isha,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.isha);

      expect(next.mode, HomePrayerSelectionMode.prayerSelection);
      expect(next.selectedPrayer, PrayerType.isha);
    });
  });
}
