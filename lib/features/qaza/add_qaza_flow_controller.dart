import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../calendar/calendar_controller.dart';

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
    this.prayerAvailability = const <PrayerType, bool>{},
    this.existingCount = 0,
    this.newCount = 0,
    this.checking = false,
    this.saving = false,
  });

  final AddQazaStep step;
  final Set<PrayerType> prayers;

  /// Per date + prayer availability across the selected dates. A prayer is
  /// selectable when it remains available on at least one selected date;
  /// unavailable combinations are skipped by creation, not by other prayers.
  final Map<PrayerType, bool> prayerAvailability;

  final int existingCount;
  final int newCount;
  final bool checking;
  final bool saving;

  bool get hasPrayers => prayers.isNotEmpty;
  bool get canAdd =>
      step == AddQazaStep.reviewAndAdd &&
      hasPrayers &&
      !checking &&
      !saving &&
      newCount > 0;

  AddQazaFlowState copyWith({
    AddQazaStep? step,
    Set<PrayerType>? prayers,
    Map<PrayerType, bool>? prayerAvailability,
    int? existingCount,
    int? newCount,
    bool? checking,
    bool? saving,
  }) =>
      AddQazaFlowState(
        step: step ?? this.step,
        prayers: prayers ?? this.prayers,
        prayerAvailability: prayerAvailability ?? this.prayerAvailability,
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
    if (_selectedDates().isEmpty) return;
    state = state.copyWith(step: AddQazaStep.selectMissedPrayers);
    await _loadPrayerAvailability();
    await refreshCounts();
  }

  /// Advances to the read-only review step with a fresh preview.
  Future<void> openReviewStep() async {
    if (!state.hasPrayers) return;
    state = state.copyWith(step: AddQazaStep.reviewAndAdd);
    await refreshCounts();
  }

  Future<void> _loadPrayerAvailability() async {
    final token = ++_request;
    final map = await ref.read(qazaServiceProvider).getAvailablePrayersByDate(
          userId: ref.read(requiredUserIdProvider),
          dates: _selectedDates(),
        );
    if (token != _request) return;
    state = state.copyWith(
      prayerAvailability: {
        for (final prayer in PrayerType.values)
          prayer: map.values.any((available) => available.contains(prayer)),
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
        if (state.prayerAvailability[prayer] ?? true) prayer,
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
    final expected = state.newCount;
    state = state.copyWith(saving: true);
    try {
      await ref.read(qazaServiceProvider).recordQazaForDates(
            userId: ref.read(requiredUserIdProvider),
            dates: _selectedDates(),
            prayerTypes: state.prayers,
          );
      return expected;
    } finally {
      if (state.saving) state = state.copyWith(saving: false);
    }
  }
}
