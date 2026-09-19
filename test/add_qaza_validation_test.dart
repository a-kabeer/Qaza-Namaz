import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_flow_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_validation.dart';

import 'support/in_memory_qaza_repository.dart';

/// The rules the Add Qaza flow is held to, and where they are applied.
void main() {
  final today = DateTime(2026, 9, 14);

  group('the rules themselves', () {
    test('a date must be in bounds and never in the future', () {
      expect(
          AddQazaValidation.isDateInBounds(DateTime(2026, 9, 13), today: today),
          isTrue);
      expect(AddQazaValidation.isDateInBounds(today, today: today), isTrue,
          reason: 'today is allowed');
      expect(
          AddQazaValidation.isDateInBounds(DateTime(2026, 9, 15), today: today),
          isFalse);
      expect(
          AddQazaValidation.isDateInBounds(DateTime(1949, 12, 31),
              today: today),
          isFalse);
      expect(AddQazaValidation.isDateInBounds(calendarFirstDate, today: today),
          isTrue);
    });

    test('a selection needs at least one date, all of them in bounds', () {
      expect(AddQazaValidation.hasValidDates(const [], today: today), isFalse);
      expect(
          AddQazaValidation.hasValidDates([DateTime(2026, 9, 13)],
              today: today),
          isTrue);
      expect(
        AddQazaValidation.hasValidDates(
            [DateTime(2026, 9, 13), DateTime(2026, 9, 15)],
            today: today),
        isFalse,
        reason: 'one future date invalidates the selection',
      );
    });

    test('a range needs two ordered ends inside the bounds', () {
      expect(
        AddQazaValidation.isRangeValid(
            [DateTime(2026, 9, 10), DateTime(2026, 9, 13)],
            today: today),
        isTrue,
      );
      expect(
        AddQazaValidation.isRangeValid(
            [DateTime(2026, 9, 13), DateTime(2026, 9, 10)],
            today: today),
        isFalse,
      );
      expect(
        AddQazaValidation.isRangeValid([DateTime(2026, 9, 10)], today: today),
        isFalse,
      );
      expect(
        AddQazaValidation.isRangeValid(
            [DateTime(2026, 9, 10), DateTime(2026, 9, 20)],
            today: today),
        isFalse,
        reason: 'the far end is in the future',
      );
    });

    test('a step is only reachable once what it needs is valid', () {
      bool canOpen(AddQazaStepRequirement step,
              {List<DateTime> dates = const [],
              Set<PrayerType> prayers = const {}}) =>
          AddQazaValidation.canOpenStep(step,
              dates: dates, prayers: prayers, today: today);

      expect(canOpen(AddQazaStepRequirement.dates), isTrue);
      expect(canOpen(AddQazaStepRequirement.prayers), isFalse);
      expect(canOpen(AddQazaStepRequirement.review), isFalse);

      final dates = [DateTime(2026, 9, 13)];
      expect(canOpen(AddQazaStepRequirement.prayers, dates: dates), isTrue);
      expect(canOpen(AddQazaStepRequirement.review, dates: dates), isFalse);
      expect(
        canOpen(AddQazaStepRequirement.review,
            dates: dates, prayers: {PrayerType.asr}),
        isTrue,
      );
    });

    test('nothing is saved without dates, prayers and something new', () {
      bool canSave({
        bool datesValid = true,
        Set<PrayerType> prayers = const {PrayerType.asr},
        int newCount = 1,
        bool checking = false,
        bool saving = false,
      }) =>
          AddQazaValidation.canSave(
            datesValid: datesValid,
            prayers: prayers,
            newCount: newCount,
            checking: checking,
            saving: saving,
          );

      expect(canSave(), isTrue);
      expect(canSave(datesValid: false), isFalse);
      expect(canSave(prayers: const {}), isFalse);
      expect(canSave(newCount: 0), isFalse);
      expect(canSave(checking: true), isFalse);
      expect(canSave(saving: true), isFalse);
    });
  });

  group('the flow applies them', () {
    late InMemoryQazaRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = InMemoryQazaRepository();
      container = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        calendarTodayProvider.overrideWithValue(today),
      ]);
      addTearDown(container.dispose);
      container.listen(addQazaFlowProvider, (_, __) {});
    });

    AddQazaFlowState flow() => container.read(addQazaFlowProvider);
    AddQazaFlowController controller() =>
        container.read(addQazaFlowProvider.notifier);

    Future<void> record(PrayerType prayer, DateTime date) {
      final ymd = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return repository.addRecord(QazaRecord(
        id: 'test-user_${prayer.name}_$ymd',
        userId: 'test-user',
        prayerType: prayer,
        originalDate: date,
        createdAt: today,
        updatedAt: today,
      ));
    }

    void selectDates(List<DateTime> dates) {
      final calendar = container.read(calendarControllerProvider.notifier);
      calendar.setSelectionMode(DateSelectionMode.multiple);
      for (final date in dates) {
        calendar.select(date);
      }
    }

    test('steps cannot be jumped to over a missing selection', () async {
      expect(
          controller().canOpenStep(AddQazaStep.selectMissedPrayers), isFalse);
      expect(controller().canOpenStep(AddQazaStep.reviewAndAdd), isFalse);

      await controller().goToStep(AddQazaStep.reviewAndAdd);
      expect(flow().step, AddQazaStep.selectDates);

      selectDates([DateTime(2026, 9, 13)]);
      expect(controller().canOpenStep(AddQazaStep.selectMissedPrayers), isTrue);
      expect(controller().canOpenStep(AddQazaStep.reviewAndAdd), isFalse);

      await controller().goToStep(AddQazaStep.reviewAndAdd);
      expect(flow().step, AddQazaStep.selectDates,
          reason: 'no prayer is selected yet');

      await controller().goToStep(AddQazaStep.selectMissedPrayers);
      expect(flow().step, AddQazaStep.selectMissedPrayers);

      await controller().togglePrayer(PrayerType.asr, selected: true);
      await controller().goToStep(AddQazaStep.reviewAndAdd);
      expect(flow().step, AddQazaStep.reviewAndAdd);
    });

    test('jumping back keeps every selection', () async {
      selectDates([DateTime(2026, 9, 13)]);
      await controller().openPrayersStep();
      await controller().togglePrayer(PrayerType.asr, selected: true);
      await controller().openReviewStep();

      await controller().goToStep(AddQazaStep.selectDates);

      expect(flow().step, AddQazaStep.selectDates);
      expect(flow().prayers, {PrayerType.asr});
      expect(container.read(calendarControllerProvider).selectedDates,
          [DateTime(2026, 9, 13)]);
      expect(controller().canOpenStep(AddQazaStep.reviewAndAdd), isTrue);
    });

    test('a partly recorded prayer is counted, not hidden', () async {
      await record(PrayerType.fajr, DateTime(2026, 9, 13));
      selectDates([DateTime(2026, 9, 12), DateTime(2026, 9, 13)]);

      await controller().openPrayersStep();

      expect(flow().selectedDateCount, 2);
      expect(flow().availableDateCount(PrayerType.fajr), 1);
      expect(flow().isPrayerAvailable(PrayerType.fajr), isTrue);
      expect(flow().isPartiallyAvailable(PrayerType.fajr), isTrue);
      // Untouched prayers are available everywhere, and are not "partial".
      expect(flow().availableDateCount(PrayerType.asr), 2);
      expect(flow().isPartiallyAvailable(PrayerType.asr), isFalse);
    });

    test('a prayer recorded on every selected date is unavailable', () async {
      await record(PrayerType.fajr, DateTime(2026, 9, 12));
      await record(PrayerType.fajr, DateTime(2026, 9, 13));
      selectDates([DateTime(2026, 9, 12), DateTime(2026, 9, 13)]);

      await controller().openPrayersStep();

      expect(flow().availableDateCount(PrayerType.fajr), 0);
      expect(flow().isPrayerAvailable(PrayerType.fajr), isFalse);
      expect(flow().isPartiallyAvailable(PrayerType.fajr), isFalse);
    });

    test('saving reports what was written, not what was previewed', () async {
      selectDates([DateTime(2026, 9, 13)]);
      await controller().openPrayersStep();
      await controller().selectAll();
      await controller().openReviewStep();
      expect(flow().newCount, 6);

      // Another device records one of the six between the preview and the tap.
      await record(PrayerType.fajr, DateTime(2026, 9, 13));

      expect(await controller().addQaza(), 5);
      expect(await repository.getRecords(userId: 'test-user'), hasLength(6));
      expect(flow().newCount, 0);
    });

    test('saving is refused when the revalidation finds nothing new', () async {
      selectDates([DateTime(2026, 9, 13)]);
      await controller().openPrayersStep();
      await controller().togglePrayer(PrayerType.asr, selected: true);
      await controller().openReviewStep();
      expect(flow().canAdd, isTrue);

      await record(PrayerType.asr, DateTime(2026, 9, 13));

      expect(await controller().addQaza(), 0);
      expect(await repository.getRecords(userId: 'test-user'), hasLength(1));
      expect(flow().newCount, 0);
      expect(flow().canAdd, isFalse);
    });

    test('a second tap while saving writes nothing more', () async {
      selectDates([DateTime(2026, 9, 13)]);
      await controller().openPrayersStep();
      await controller().togglePrayer(PrayerType.asr, selected: true);
      await controller().openReviewStep();

      final first = controller().addQaza();
      final second = await controller().addQaza();
      expect(await first, 1);

      expect(second, 0);
      expect(await repository.getRecords(userId: 'test-user'), hasLength(1));
    });
  });
}
