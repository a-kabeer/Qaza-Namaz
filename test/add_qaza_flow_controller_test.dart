import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/prayer_times/domain/prayer_times_models.dart';
import 'package:qaza_namaz/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:qaza_namaz/features/prayer_times/prayer_times_providers.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_flow_controller.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  final today = DateTime(2026, 9, 14);
  late InMemoryQazaRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemoryQazaRepository();
    container = ProviderContainer(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        prayerTimesRepositoryProvider
            .overrideWithValue(_FakePrayerTimesRepository()),
        prayerTimesClockProvider.overrideWithValue(
          _FixedPrayerClock(DateTime.utc(2026, 9, 14, 3)),
        ),
        activeUserIdProvider.overrideWithValue('test-user'),
        calendarTodayProvider.overrideWithValue(today),
      ],
    );
    addTearDown(container.dispose);
    // The flow provider is auto-dispose; a listener keeps it alive for the test.
    container.listen(addQazaFlowProvider, (_, __) {});
  });

  AddQazaFlowState flow() => container.read(addQazaFlowProvider);

  Future<void> addFajrOn(DateTime date) {
    final ymd =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return repository.addRecord(QazaRecord(
      id: 'test-user_fajr_$ymd',
      userId: 'test-user',
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: today,
      updatedAt: today,
    ));
  }

  test('today disables prayers whose current waqt has not ended', () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(today);
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();

    expect(flow().prayerAvailability[PrayerType.fajr], isTrue);
    expect(flow().prayerAvailability[PrayerType.zuhr], isFalse);
    expect(flow().prayerAvailability[PrayerType.asr], isFalse);
    expect(flow().prayerAvailability[PrayerType.maghrib], isFalse);
    expect(flow().prayerAvailability[PrayerType.isha], isFalse);
    expect(flow().prayerAvailability[PrayerType.witr], isFalse);

    await controller.togglePrayer(PrayerType.zuhr, selected: true);
    expect(flow().newCount, 0);

    controller.clearPrayers();
    await controller.togglePrayer(PrayerType.fajr, selected: true);
    expect(flow().newCount, 1);
    expect(await controller.addQaza(), 0);
    await controller.openReviewStep();
    expect(await controller.addQaza(), 1);
  });

  test('openPrayersStep is a no-op without dates', () async {
    await container.read(addQazaFlowProvider.notifier).openPrayersStep();
    expect(flow().step, AddQazaStep.selectDates);
  });

  test(
      'prayer availability is evaluated per date + prayer and Select All excludes unavailable prayers',
      () async {
    await addFajrOn(DateTime(2026, 9, 13));
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();

    expect(flow().prayerAvailability[PrayerType.fajr], isFalse);
    expect(flow().prayerAvailability[PrayerType.witr], isTrue);

    await controller.selectAll();
    expect(flow().prayers.contains(PrayerType.fajr), isFalse);
    expect(flow().prayers.length, 5);
    // The unavailable Fajr combination was excluded from the selection, so
    // every selected combination is new.
    expect(flow().existingCount, 0);
    expect(flow().newCount, 5);
  });

  test(
      'a prayer unavailable on one date stays available when another date is selected',
      () async {
    await addFajrOn(DateTime(2026, 9, 13));
    final calendarController =
        container.read(calendarControllerProvider.notifier);
    calendarController.setSelectionMode(DateSelectionMode.multiple);
    calendarController.select(DateTime(2026, 9, 12));
    calendarController.select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();

    expect(flow().prayerAvailability[PrayerType.fajr], isTrue);
    await controller.selectAll();
    expect(flow().prayers.length, 6);
    expect(flow().existingCount, 1); // Fajr on 9-13 is already recorded
    expect(flow().newCount, 11); // 12 combinations minus one existing
  });

  test('toggle and clear keep the preview in sync', () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();

    await controller.togglePrayer(PrayerType.asr, selected: true);
    expect(flow().newCount, 1);
    expect(flow().existingCount, 0);

    await controller.togglePrayer(PrayerType.witr, selected: true);
    expect(flow().newCount, 2);
    expect(flow().prayers, {PrayerType.asr, PrayerType.witr});

    controller.clearPrayers();
    expect(flow().prayers, isEmpty);
    expect(flow().newCount, 0);
    expect(flow().existingCount, 0);
  });

  test('clearing during a preview prevents stale counts from returning',
      () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();
    final pending = controller.togglePrayer(PrayerType.asr, selected: true);
    expect(flow().checking, isTrue);
    controller.clearPrayers();
    await pending;
    expect(flow().prayers, isEmpty);
    expect(flow().newCount, 0);
    expect(flow().existingCount, 0);
    expect(flow().checking, isFalse);
    expect(flow().canAdd, isFalse);
  });

  test('back walks the steps in reverse and preserves the workflow state',
      () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();
    await controller.togglePrayer(PrayerType.asr, selected: true);
    await controller.openReviewStep();
    expect(flow().step, AddQazaStep.reviewAndAdd);

    controller.back();
    expect(flow().step, AddQazaStep.selectMissedPrayers);
    expect(flow().prayers, {PrayerType.asr});
    expect(flow().newCount, 1);

    controller.back();
    expect(flow().step, AddQazaStep.selectDates);
    expect(flow().prayers, {PrayerType.asr});
  });

  test('openReviewStep requires a prayer selection', () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();
    await controller.openReviewStep();
    expect(flow().step, AddQazaStep.selectMissedPrayers);
  });

  test('addQaza creates one record per combination and replays are idempotent',
      () async {
    container
        .read(calendarControllerProvider.notifier)
        .select(DateTime(2026, 9, 13));
    final controller = container.read(addQazaFlowProvider.notifier);
    await controller.openPrayersStep();
    await controller.selectAll();

    expect(await controller.addQaza(), 0);
    expect(await repository.getRecords(userId: 'test-user'), isEmpty);
    await controller.openReviewStep();
    expect(await controller.addQaza(), 6);
    var records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(6));
    expect(
        records.every((record) => record.status == QazaStatus.pending), isTrue);
    expect(records.where((record) => record.prayerType == PrayerType.witr),
        hasLength(1));
    expect(
      records.map((record) => record.id).toSet(),
      records.map((record) => record.id).toSet(), // deterministic ids
    );

    await controller.refreshCounts();
    expect(flow().newCount, 0);
    expect(await controller.addQaza(), 0);
    records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(6));
  });
}


class _FixedPrayerClock implements PrayerTimesClock {
  const _FixedPrayerClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}

class _FakePrayerTimesRepository implements PrayerTimesRepository {
  static const _timezone = 'Asia/Karachi';

  const _FakePrayerTimesRepository();

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    return PrayerDay(
      date: day,
      timezone: timezone ?? _timezone,
      times: const {
        PrayerName.fajr: PrayerTime(hour: 5, minute: 0),
        PrayerName.sunrise: PrayerTime(hour: 6, minute: 0),
        PrayerName.dhuhr: PrayerTime(hour: 12, minute: 0),
        PrayerName.asr: PrayerTime(hour: 15, minute: 0),
        PrayerName.maghrib: PrayerTime(hour: 18, minute: 0),
        PrayerName.isha: PrayerTime(hour: 19, minute: 0),
      },
      hijriDate: const HijriDate(day: 1, month: 'Muharram', year: 1448),
      fetchedAt: DateTime.utc(2026, 9, 14),
    );
  }

  @override
  Future<PrayerLocation?> getSavedLocation() async => const PrayerLocation(
        latitude: 24.86,
        longitude: 67.01,
        timezone: _timezone,
      );

  @override
  Future<void> saveLocation(PrayerLocation location) async {}

  @override
  Future<PrayerSettings> getSavedSettings() async =>
      const PrayerSettings();

  @override
  Future<void> saveSettings(PrayerSettings settings) async {}
}
