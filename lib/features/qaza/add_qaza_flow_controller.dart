import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../calendar/calendar_controller.dart';
import 'add_qaza_validation.dart';
import '../../domain/entities/qaza_operation.dart';

/// The three steps of the Add Qaza workflow.
enum AddQazaStep { selectDates, selectMissedPrayers, reviewAndAdd }

/// Temporary workflow state for Add Qaza.
///
/// Selected dates (and the date mode) are owned by the shared
/// [calendarControllerProvider] as the single source of truth. This controller
/// owns only the step position, the prayer selection and the derived
/// availability/counts, so every back transition preserves the workflow state
/// without duplicating state sources.
class AddQazaFlowState {
  const AddQazaFlowState({
    this.step = AddQazaStep.selectDates,
    this.prayers = const <PrayerType>{},
    this.prayerAvailableDates = const <PrayerType, int>{},
    this.selectedDateCount = 0,
    this.existingCount = 0,
    this.newCount = 0,
    this.checking = false,
    this.saving = false,
  });

  final AddQazaStep step;
  final Set<PrayerType> prayers;

  /// How many of the selected dates still have each prayer eligible.
  ///
  /// A prayer is selectable while that count is above zero; a count between
  /// one and [selectedDateCount] is a partial availability the user is told
  /// about rather than silently given. Unavailable combinations are skipped
  /// by creation, never by excluding the whole prayer.
  final Map<PrayerType, int> prayerAvailableDates;

  /// The number of dates the counts above were measured against.
  final int selectedDateCount;

  final int existingCount;
  final int newCount;
  final bool checking;
  final bool saving;

  bool get hasPrayers => prayers.isNotEmpty;

  /// Whether [prayer] is still eligible on at least one selected date.
  bool isPrayerAvailable(PrayerType prayer) =>
      (prayerAvailableDates[prayer] ?? 1) > 0;

  /// How many selected dates still have [prayer] eligible.
  int availableDateCount(PrayerType prayer) =>
      prayerAvailableDates[prayer] ?? selectedDateCount;

  /// True when a prayer is eligible on some, but not all, selected dates.
  bool isPartiallyAvailable(PrayerType prayer) {
    final available = availableDateCount(prayer);
    return available > 0 && available < selectedDateCount;
  }

  /// Kept as a view over the counts so availability has one source.
  Map<PrayerType, bool> get prayerAvailability => {
        for (final entry in prayerAvailableDates.entries)
          entry.key: entry.value > 0,
      };

  /// The same rule the save path applies, one step earlier.
  bool get canAdd =>
      step == AddQazaStep.reviewAndAdd &&
      AddQazaValidation.canSave(
        datesValid: selectedDateCount > 0,
        prayers: prayers,
        newCount: newCount,
        checking: checking,
        saving: saving,
      );

  AddQazaFlowState copyWith({
    AddQazaStep? step,
    Set<PrayerType>? prayers,
    Map<PrayerType, int>? prayerAvailableDates,
    int? selectedDateCount,
    int? existingCount,
    int? newCount,
    bool? checking,
    bool? saving,
  }) =>
      AddQazaFlowState(
        step: step ?? this.step,
        prayers: prayers ?? this.prayers,
        prayerAvailableDates: prayerAvailableDates ?? this.prayerAvailableDates,
        selectedDateCount: selectedDateCount ?? this.selectedDateCount,
        existingCount: existingCount ?? this.existingCount,
        newCount: newCount ?? this.newCount,
        checking: checking ?? this.checking,
        saving: saving ?? this.saving,
      );
}

/// Auto-disposed with the Add Qaza screen so a reopened flow always starts
/// clean, while staying alive across every in-screen back transition.
final addQazaFlowProvider =
    NotifierProvider.autoDispose<AddQazaFlowController, AddQazaFlowState>(
  AddQazaFlowController.new,
);

class AddQazaFlowController extends AutoDisposeNotifier<AddQazaFlowState> {
  /// Monotonic token; only the latest async recomputation may publish state.
  int _request = 0;

  @override
  AddQazaFlowState build() => const AddQazaFlowState();

  List<DateTime> _selectedDates() => ref
      .read(calendarControllerProvider)
      .datesForStorage
      .toList(growable: false);

  DateTime get _today => ref.read(calendarTodayProvider);

  static AddQazaStepRequirement _requirement(AddQazaStep step) =>
      switch (step) {
        AddQazaStep.selectDates => AddQazaStepRequirement.dates,
        AddQazaStep.selectMissedPrayers => AddQazaStepRequirement.prayers,
        AddQazaStep.reviewAndAdd => AddQazaStepRequirement.review,
      };

  /// Whether [target] may be opened right now.
  ///
  /// The step indicator asks this before it offers a step, and [goToStep]
  /// asks again before it moves, so a tap can never step over a rule.
  bool canOpenStep(AddQazaStep target) =>
      target == state.step ||
      AddQazaValidation.canOpenStep(
        _requirement(target),
        dates: _selectedDates(),
        prayers: state.prayers,
        today: _today,
      );

  /// Moves to [target] when its own requirements are met, refreshing whatever
  /// that step shows. Selections are never discarded on the way.
  Future<void> goToStep(AddQazaStep target) async {
    if (target == state.step || !canOpenStep(target)) return;
    switch (target) {
      case AddQazaStep.selectDates:
        state = state.copyWith(step: target);
      case AddQazaStep.selectMissedPrayers:
        await openPrayersStep();
      case AddQazaStep.reviewAndAdd:
        await openReviewStep();
    }
  }

  void back() {
    final previous = switch (state.step) {
      AddQazaStep.reviewAndAdd => AddQazaStep.selectMissedPrayers,
      AddQazaStep.selectMissedPrayers => AddQazaStep.selectDates,
      _ => AddQazaStep.selectDates,
    };
    state = state.copyWith(step: previous);
  }

  /// Advances from Select Dates to Select Missed Prayers, refreshing the
  /// per date + prayer availability and the preview counts for the selection.
  Future<void> openPrayersStep() async {
    if (!AddQazaValidation.hasValidDates(_selectedDates(), today: _today)) {
      return;
    }
    state = state.copyWith(step: AddQazaStep.selectMissedPrayers);
    await _loadPrayerAvailability();
    await refreshCounts();
  }

  /// Advances to the read-only review step with a fresh preview.
  Future<void> openReviewStep() async {
    if (!AddQazaValidation.canOpenStep(
      AddQazaStepRequirement.review,
      dates: _selectedDates(),
      prayers: state.prayers,
      today: _today,
    )) {
      return;
    }
    state = state.copyWith(step: AddQazaStep.reviewAndAdd);
    await refreshCounts();
  }

  Future<void> _loadPrayerAvailability() async {
    final token = ++_request;
    final dates = _selectedDates();
    final map = await ref.read(qazaServiceProvider).getAvailablePrayersByDate(
          userId: ref.read(requiredUserIdProvider),
          dates: dates,
        );
    if (token != _request) return;
    state = state.copyWith(
      selectedDateCount: dates.length,
      prayerAvailableDates: {
        for (final prayer in PrayerType.values)
          prayer: map.values
              .where((available) => available.contains(prayer))
              .length,
      },
    );
  }

  /// Recomputes the preview with the same bounded business rules that creation
  /// uses, so the review numbers match the final save-time revalidation.
  Future<void> refreshCounts() async {
    final token = ++_request;
    final dates = _selectedDates();
    final prayers = state.prayers;
    if (dates.isEmpty || prayers.isEmpty) {
      state = state.copyWith(existingCount: 0, newCount: 0, checking: false);
      return;
    }
    state = state.copyWith(checking: true);
    try {
      final analysis = await ref.read(qazaServiceProvider).analyzeAvailability(
            userId: ref.read(requiredUserIdProvider),
            dates: dates,
            prayerTypes: prayers,
          );
      if (token != _request) return;
      state = state.copyWith(
        existingCount: analysis.unavailableCount,
        newCount: analysis.newCount,
        checking: false,
      );
    } finally {
      if (token == _request && state.checking) {
        state = state.copyWith(checking: false);
      }
    }
  }

  Future<void> togglePrayer(PrayerType prayer, {required bool selected}) async {
    if (selected && !state.isPrayerAvailable(prayer)) return;
    final prayers = {...state.prayers};
    if (selected) {
      prayers.add(prayer);
    } else {
      prayers.remove(prayer);
    }
    state = state.copyWith(prayers: prayers);
    await refreshCounts();
  }

  /// Select All only selects prayers that remain available on at least one
  /// selected date, so fully unavailable combinations are excluded.
  Future<void> selectAll() async {
    final prayers = <PrayerType>{
      for (final prayer in PrayerType.values)
        if (state.isPrayerAvailable(prayer)) prayer,
    };
    if (prayers.isEmpty) return;
    state = state.copyWith(prayers: prayers);
    await refreshCounts();
  }

  void clearPrayers() {
    ++_request;
    state = state.copyWith(
      prayers: const <PrayerType>{},
      existingCount: 0,
      newCount: 0,
      checking: false,
    );
  }

  /// Creates one pending record per eligible date x prayer combination.
  ///
  /// Creation revalidates availability with the same bounded analysis as the
  /// preview, and the repository insert is duplicate-protected and idempotent
  /// (deterministic record id + unique user/prayer/date key), so stale previews
  /// or double taps cannot create duplicates.
  Future<int> addQaza() async {
    if (!state.canAdd) return 0;
    final dates = _selectedDates();
    final prayers = state.prayers;
    state = state.copyWith(saving: true);
    try {
      // The preview may be a minute old and another device may have written
      // in the meantime, so the selection is judged once more against the
      // ledger as it is now — and the rules say whether to go on.
      final analysis = await ref.read(qazaServiceProvider).analyzeAvailability(
            userId: ref.read(requiredUserIdProvider),
            dates: dates,
            prayerTypes: prayers,
          );
      if (!AddQazaValidation.canSave(
        datesValid: AddQazaValidation.hasValidDates(dates, today: _today),
        prayers: prayers,
        newCount: analysis.newCount,
        checking: false,
        saving: false,
      )) {
        state = state.copyWith(
          existingCount: analysis.unavailableCount,
          newCount: analysis.newCount,
        );
        return 0;
      }

      final selectionMode = ref.read(calendarControllerProvider).selectionMode;
      final operationType = switch (selectionMode) {
        DateSelectionMode.single => QazaOperationType.singleDateAdd,
        DateSelectionMode.range => QazaOperationType.rangeAdd,
        DateSelectionMode.multiple => QazaOperationType.multipleDateAdd,
      };
      final inputSnapshot = <String, dynamic>{
        'version': 1,
        'selectionMode': selectionMode.name,
        'dates': dates
            .map((date) => DateTime(date.year, date.month, date.day).toIso8601String())
            .toList(growable: false),
        'prayers': [
          for (final prayer in PrayerType.values)
            if (prayers.contains(prayer)) prayer.name,
        ],
      };
      final operation = await ref.read(qazaOperationServiceProvider).begin(
            userId: ref.read(requiredUserIdProvider),
            type: operationType,
            inputSnapshot: inputSnapshot,
          );
      var processed = 0;
      try {
        final created = await ref.read(qazaServiceProvider).recordQazaForDates(
              userId: ref.read(requiredUserIdProvider),
              dates: dates,
              prayerTypes: prayers,
              operationId: operation.operationId,
              operationCreatedAt: operation.createdAt,
              onProgress: (value, _) => processed = value,
            );
        await ref.read(qazaOperationServiceProvider).finish(
              operation,
              status: QazaOperationStatus.completed,
              affectedRecordCount: created,
            );
        state = state.copyWith(
          existingCount: analysis.unavailableCount + created,
          newCount: 0,
        );
        return created;
      } catch (error) {
        await ref.read(qazaOperationServiceProvider).finish(
              operation,
              status: processed > 0
                  ? QazaOperationStatus.partial
                  : QazaOperationStatus.failed,
              affectedRecordCount: processed,
              note: error.toString(),
            );
        rethrow;
      }
    } finally {
      if (state.saving) state = state.copyWith(saving: false);
    }
  }
}