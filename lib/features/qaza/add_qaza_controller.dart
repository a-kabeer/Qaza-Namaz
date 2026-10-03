import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../domain/services/profile_rules.dart';
import '../../domain/services/qaza_availability_service.dart';
import '../../domain/services/qaza_service.dart';
import '../calendar/calendar_controller.dart';

enum AddQazaCandidateStatus {
  newRecord,
  alreadyAdded,
  unavailable,
}

@immutable
class AddQazaCandidate {
  const AddQazaCandidate({
    required this.key,
    required this.status,
  });

  final QazaPrayerKey key;
  final AddQazaCandidateStatus status;
}

@immutable
class AddQazaAnalysis {
  const AddQazaAnalysis({required this.items});

  final List<AddQazaCandidate> items;

  int get total => items.length;
  int get newCount => items
      .where((item) => item.status == AddQazaCandidateStatus.newRecord)
      .length;
  int get existingCount => items
      .where((item) => item.status == AddQazaCandidateStatus.alreadyAdded)
      .length;
  int get unavailableCount => items
      .where((item) => item.status == AddQazaCandidateStatus.unavailable)
      .length;

  /// Number of new records that will actually be created for [prayer].
  int countForPrayer(PrayerType prayer) => items
      .where(
        (item) =>
            item.key.prayerType == prayer &&
            item.status == AddQazaCandidateStatus.newRecord,
      )
      .length;

  Set<PrayerType> get newPrayers => {
        for (final item in items)
          if (item.status == AddQazaCandidateStatus.newRecord)
            item.key.prayerType,
      };

  int get statusCountTotal => newCount + existingCount + unavailableCount;

  static const empty = AddQazaAnalysis(
    items: <AddQazaCandidate>[],
  );
}

@immutable
class AddQazaState {
  const AddQazaState({
    this.mode = DateSelectionMode.single,
    this.selectedDates = const <DateTime>[],
    this.selectedPrayers = const <PrayerType>{
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    },
    this.addablePrayers = const <PrayerType>{
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    },
    this.selectedDateAvailability =
        const <DateTime, Set<PrayerType>>{},
    this.calendarAvailability = const <DateTime, Set<PrayerType>>{},
    this.calendarLoading = true,
    this.prayerAvailabilityLoading = false,
    this.analysisLoading = false,
    this.analysis = AddQazaAnalysis.empty,
    this.error,
  });

  final DateSelectionMode mode;
  final List<DateTime> selectedDates;
  final Set<PrayerType> selectedPrayers;

  /// Prayers with at least one new occurrence across the selected dates.
  final Set<PrayerType> addablePrayers;

  /// Exact prayer availability for the currently selected dates.
  final Map<DateTime, Set<PrayerType>> selectedDateAvailability;

  final Map<DateTime, Set<PrayerType>> calendarAvailability;
  final bool calendarLoading;
  final bool prayerAvailabilityLoading;
  final bool analysisLoading;
  final AddQazaAnalysis analysis;
  final Object? error;

  bool get canReview =>
      selectedDates.isNotEmpty &&
      selectedPrayers.isNotEmpty &&
      analysis.newCount > 0 &&
      !prayerAvailabilityLoading &&
      !analysisLoading;

  AddQazaState copyWith({
    DateSelectionMode? mode,
    List<DateTime>? selectedDates,
    Set<PrayerType>? selectedPrayers,
    Set<PrayerType>? addablePrayers,
    Map<DateTime, Set<PrayerType>>? selectedDateAvailability,
    Map<DateTime, Set<PrayerType>>? calendarAvailability,
    bool? calendarLoading,
    bool? prayerAvailabilityLoading,
    bool? analysisLoading,
    AddQazaAnalysis? analysis,
    Object? error,
    bool clearError = false,
  }) =>
      AddQazaState(
        mode: mode ?? this.mode,
        selectedDates: selectedDates ?? this.selectedDates,
        selectedPrayers: selectedPrayers ?? this.selectedPrayers,
        addablePrayers: addablePrayers ?? this.addablePrayers,
        selectedDateAvailability:
            selectedDateAvailability ?? this.selectedDateAvailability,
        calendarAvailability:
            calendarAvailability ?? this.calendarAvailability,
        calendarLoading: calendarLoading ?? this.calendarLoading,
        prayerAvailabilityLoading:
            prayerAvailabilityLoading ?? this.prayerAvailabilityLoading,
        analysisLoading: analysisLoading ?? this.analysisLoading,
        analysis: analysis ?? this.analysis,
        error: clearError ? null : error ?? this.error,
      );
}

final addQazaControllerProvider =
    AutoDisposeNotifierProvider<AddQazaController, AddQazaState>(
  AddQazaController.new,
);

/// Feature-specific date-selection rules for Add Qaza.
class AddQazaSelectionRules {
  const AddQazaSelectionRules._();

  static List<DateTime> normalizeForMode({
    required DateSelectionMode mode,
    required Iterable<DateTime> dates,
    required Map<DateTime, Set<PrayerType>> availability,
  }) {
    final canonical = dates.map(QazaDate.normalize).toSet().toList()..sort();

    switch (mode) {
      case DateSelectionMode.range:
        // Range intentionally ignores prayer availability.
        return List.unmodifiable(canonical);
      case DateSelectionMode.single:
        if (canonical.isEmpty) return const <DateTime>[];
        final endpoint = canonical.last;
        return availability[endpoint]?.isNotEmpty == true
            ? <DateTime>[endpoint]
            : const <DateTime>[];
      case DateSelectionMode.multiple:
        return List.unmodifiable(
          canonical.where(
            (date) => availability[date]?.isNotEmpty == true,
          ),
        );
    }
  }

  static bool hasAvailablePrayer(
    DateTime date,
    Map<DateTime, Set<PrayerType>> availability,
  ) =>
      availability[QazaDate.normalize(date)]?.isNotEmpty == true;

  static Set<PrayerType> unionAvailablePrayers(
    Iterable<DateTime> dates,
    Map<DateTime, Set<PrayerType>> availability,
  ) {
    final result = <PrayerType>{};
    for (final date in dates) {
      result.addAll(
        availability[QazaDate.normalize(date)] ?? const <PrayerType>{},
      );
    }
    return result;
  }
}

class AddQazaController extends AutoDisposeNotifier<AddQazaState> {
  DateTime? _visibleMonth;
  bool _disposed = false;
  bool _syncingCalendarSelection = false;
  int _calendarRequest = 0;
  int _prayerAvailabilityRequest = 0;
  int _analysisRequest = 0;

  @override
  AddQazaState build() {
    ref.listen<CalendarSelectionState>(
      calendarControllerProvider,
      (_, next) => _onCalendarSelectionChanged(next),
    );
    ref.listen<AsyncValue<UserProfile?>>(
      userProfileProvider,
      (_, __) => _onProfileChanged(),
    );
    ref.onDispose(() {
      _disposed = true;
      ref.read(calendarControllerProvider.notifier).clear();
    });

    Future.microtask(() {
      if (_disposed) return;
      ref.read(calendarControllerProvider.notifier).clear();

      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null) {
        final prayers = <PrayerType>{
          PrayerType.fajr,
          PrayerType.zuhr,
          PrayerType.asr,
          PrayerType.maghrib,
          PrayerType.isha,
        };
        if (ProfileRules.effectiveWitr(profile)) {
          prayers.add(PrayerType.witr);
        }
        state = state.copyWith(
          selectedPrayers: Set.unmodifiable(prayers),
        );
      }

      _onCalendarSelectionChanged(
        ref.read(calendarControllerProvider),
      );
    });

    return const AddQazaState();
  }

  void restoreFromSnapshot(QazaAdditionInputSnapshot snapshot) {
    final mode = switch (snapshot.mode) {
      QazaAdditionMode.single => DateSelectionMode.single,
      QazaAdditionMode.range => DateSelectionMode.range,
      QazaAdditionMode.multiple => DateSelectionMode.multiple,
    };

    state = state.copyWith(
      mode: mode,
      selectedDates: List.unmodifiable(
        snapshot.selectedDates.map(QazaDate.normalize),
      ),
      selectedPrayers: Set.unmodifiable(snapshot.selectedPrayers.toSet()),
      analysis: AddQazaAnalysis.empty,
      clearError: true,
    );

    _restoreCalendarSelection(
      mode: mode,
      dates: snapshot.selectedDates,
    );
    if (snapshot.selectedDates.isNotEmpty) {
      final first = QazaDate.normalize(snapshot.selectedDates.first);
      unawaited(refreshCalendarMonth(first));
    }
    unawaited(_refreshPrayerAvailability());
  }

  void setMode(DateSelectionMode mode) {
    final current = state;
    if (mode == current.mode) return;

    if (current.mode == DateSelectionMode.range &&
        (mode == DateSelectionMode.single ||
            mode == DateSelectionMode.multiple) &&
        _hasCompleteAvailabilitySnapshot(current.selectedDates)) {
      final normalized = AddQazaSelectionRules.normalizeForMode(
        mode: mode,
        dates: current.selectedDates,
        availability: current.selectedDateAvailability,
      );
      _restoreCalendarSelection(mode: mode, dates: normalized);
      _refreshPrayerAvailability();
      return;
    }

    ref.read(calendarControllerProvider.notifier).setSelectionMode(mode);
  }

  void togglePrayer(PrayerType prayer) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (prayer == PrayerType.witr &&
        profile != null &&
        !ProfileRules.effectiveWitr(profile)) {
      return;
    }

    // Once dates are selected, never allow a prayer with no addable
    // occurrence to re-enter the selection.
    if (state.selectedDates.isNotEmpty &&
        (state.prayerAvailabilityLoading ||
            !state.addablePrayers.contains(prayer))) {
      return;
    }

    final next = Set<PrayerType>.of(state.selectedPrayers);
    if (!next.add(prayer)) {
      next.remove(prayer);
    }

    state = state.copyWith(
      selectedPrayers: Set.unmodifiable(next),
      analysis: AddQazaAnalysis.empty,
    );
    _refreshAnalysis();
  }

  DateTime? get startPrayingDate {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return null;
    final date = ProfileRules.startPrayingDate(profile);
    return date == null ? null : QazaDate.normalize(date);
  }

  DateTime get today => QazaDate.normalize(
        ref.read(calendarTodayProvider),
      );

  Future<void> refreshCalendarMonth(DateTime month) async {
    _visibleMonth = DateTime(month.year, month.month, 1);
    final request = ++_calendarRequest;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    state = state.copyWith(
      calendarLoading: true,
      clearError: true,
    );

    final dates = _monthDates(_visibleMonth!);
    final prayers = _profileAllowedPrayers(profile);

    try {
      final available =
          await ref.read(qazaServiceProvider).getAvailablePrayersByDate(
                userId: ref.read(requiredUserIdProvider),
                dates: dates,
                prayerTypes: prayers,
              );

      if (_disposed || request != _calendarRequest) return;

      state = state.copyWith(
        calendarAvailability: _applyDateRules(
          available,
          dates,
          profile,
        ),
        calendarLoading: false,
      );
    } catch (error) {
      if (_disposed || request != _calendarRequest) return;
      state = state.copyWith(
        calendarLoading: false,
        error: error,
      );
    }
  }

  bool isDateAllowed(DateTime date) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    return profile != null && _dateAllowed(date, profile);
  }

  Future<AddQazaAnalysis> refreshAnalysis() async {
    final dates = List<DateTime>.of(state.selectedDates);
    final prayers = Set<PrayerType>.of(state.selectedPrayers);

    if (dates.isEmpty || prayers.isEmpty) {
      const empty = AddQazaAnalysis.empty;
      state = state.copyWith(
        analysis: empty,
        analysisLoading: false,
      );
      return empty;
    }

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return AddQazaAnalysis.empty;

    final request = ++_analysisRequest;
    state = state.copyWith(
      analysisLoading: true,
      clearError: true,
    );

    try {
      final raw = await ref.read(qazaServiceProvider).analyzeAvailability(
            userId: ref.read(requiredUserIdProvider),
            dates: dates,
            prayerTypes: prayers,
          );

      final newKeys = raw.newCandidates.toSet();
      final existingKeys = raw.existingCandidates.toSet();

      final items = [
        for (final key in raw.candidates)
          AddQazaCandidate(
            key: key,
            status: !_dateAllowed(key.date, profile) ||
                    (key.prayerType == PrayerType.witr &&
                        !ProfileRules.effectiveWitr(profile))
                ? AddQazaCandidateStatus.unavailable
                : newKeys.contains(key)
                    ? AddQazaCandidateStatus.newRecord
                    : existingKeys.contains(key)
                        ? AddQazaCandidateStatus.alreadyAdded
                        : AddQazaCandidateStatus.unavailable,
          ),
      ]..sort((a, b) {
          final dateCompare = a.key.date.compareTo(b.key.date);
          if (dateCompare != 0) return dateCompare;
          return a.key.prayerType.qazaSequenceIndex
              .compareTo(b.key.prayerType.qazaSequenceIndex);
        });

      final analysis = AddQazaAnalysis(
        items: List.unmodifiable(items),
      );

      if (_disposed || request != _analysisRequest) return analysis;

      state = state.copyWith(
        analysis: analysis,
        analysisLoading: false,
      );
      return analysis;
    } catch (error) {
      if (!_disposed && request == _analysisRequest) {
        state = state.copyWith(
          analysisLoading: false,
          error: error,
        );
      }
      rethrow;
    }
  }

  void _onProfileChanged() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null || _disposed) return;

    final selected = Set<PrayerType>.of(state.selectedPrayers);
    if (!ProfileRules.effectiveWitr(profile)) {
      selected.remove(PrayerType.witr);
    }

    state = state.copyWith(
      selectedPrayers: Set.unmodifiable(selected),
    );

    final visible = _visibleMonth;
    if (visible != null) refreshCalendarMonth(visible);
    _refreshPrayerAvailability();
  }

  void _onCalendarSelectionChanged(CalendarSelectionState next) {
    final dates =
        next.datesForStorage.map(QazaDate.normalize).toList(growable: false);

    state = state.copyWith(
      mode: next.selectionMode,
      selectedDates: List.unmodifiable(dates),
      clearError: true,
    );
    if (_syncingCalendarSelection) return;
    _refreshPrayerAvailability();
  }

  bool _hasCompleteAvailabilitySnapshot(Iterable<DateTime> dates) {
    final availability = state.selectedDateAvailability;
    return dates.every(
      (date) => availability.containsKey(QazaDate.normalize(date)),
    );
  }

  bool _sameDates(Iterable<DateTime> a, Iterable<DateTime> b) {
    final left = a.map(QazaDate.normalize).toList()..sort();
    final right = b.map(QazaDate.normalize).toList()..sort();
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _restoreCalendarSelection({
    required DateSelectionMode mode,
    required Iterable<DateTime> dates,
  }) {
    final canonical = dates.map(QazaDate.normalize).toSet().toList()..sort();
    _syncingCalendarSelection = true;
    try {
      ref.read(calendarControllerProvider.notifier).restoreSelection(
            mode: mode,
            dates: canonical,
          );
    } finally {
      _syncingCalendarSelection = false;
    }
  }

  Future<void> _refreshPrayerAvailability() async {
    final dates = List<DateTime>.of(state.selectedDates);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    // Any date/mode change invalidates analysis that may still be in flight.
    ++_analysisRequest;

    final allowed = _profileAllowedPrayers(profile).toSet();
    if (dates.isEmpty) {
      final selected = Set<PrayerType>.of(state.selectedPrayers)
        ..retainAll(allowed);
      state = state.copyWith(
        addablePrayers: Set.unmodifiable(allowed),
        selectedDateAvailability:
            const <DateTime, Set<PrayerType>>{},
        selectedPrayers: Set.unmodifiable(selected),
        prayerAvailabilityLoading: false,
        analysis: AddQazaAnalysis.empty,
        analysisLoading: false,
      );
      return;
    }

    final request = ++_prayerAvailabilityRequest;
    state = state.copyWith(
      selectedDateAvailability:
          const <DateTime, Set<PrayerType>>{},
      prayerAvailabilityLoading: true,
      analysis: AddQazaAnalysis.empty,
      clearError: true,
    );

    try {
      final raw = await ref.read(qazaServiceProvider).analyzeAvailability(
            userId: ref.read(requiredUserIdProvider),
            dates: dates,
            prayerTypes: allowed,
          );

      if (_disposed || request != _prayerAvailabilityRequest) return;

      final availableByDate = <DateTime, Set<PrayerType>>{
        for (final date in dates) QazaDate.normalize(date): <PrayerType>{},
      };
      for (final key in raw.newCandidates) {
        final date = QazaDate.normalize(key.date);
        if (_dateAllowed(key.date, profile) &&
            allowed.contains(key.prayerType) &&
            availableByDate.containsKey(date)) {
          availableByDate[date]!.add(key.prayerType);
        }
      }

      final normalizedDates = AddQazaSelectionRules.normalizeForMode(
        mode: state.mode,
        dates: dates,
        availability: availableByDate,
      );
      final normalizedAvailability = <DateTime, Set<PrayerType>>{
        for (final date in normalizedDates)
          QazaDate.normalize(date):
              Set.unmodifiable(availableByDate[QazaDate.normalize(date)] ??
                  const <PrayerType>{}),
      };
      final addable = AddQazaSelectionRules.unionAvailablePrayers(
        normalizedDates,
        normalizedAvailability,
      );
      final selected = Set<PrayerType>.of(state.selectedPrayers);
      if (normalizedDates.isNotEmpty) {
        selected.retainAll(addable);
      } else {
        selected.retainAll(allowed);
      }

      final currentCalendar = ref.read(calendarControllerProvider);
      if (!_sameDates(
        currentCalendar.datesForStorage,
        normalizedDates,
      ) ||
          currentCalendar.selectionMode != state.mode) {
        _restoreCalendarSelection(
          mode: state.mode,
          dates: normalizedDates,
        );
      }

      state = state.copyWith(
        selectedDates: List.unmodifiable(normalizedDates),
        selectedDateAvailability: Map.unmodifiable(
          normalizedAvailability,
        ),
        addablePrayers: Set.unmodifiable(addable),
        selectedPrayers: Set.unmodifiable(selected),
        prayerAvailabilityLoading: false,
      );

      await refreshAnalysis();
    } catch (error) {
      if (_disposed || request != _prayerAvailabilityRequest) return;
      state = state.copyWith(
        prayerAvailabilityLoading: false,
        error: error,
      );
    }
  }

  Future<void> _refreshAnalysis() async {
    try {
      await refreshAnalysis();
    } catch (_) {}
  }

  List<PrayerType> _profileAllowedPrayers(UserProfile profile) =>
      ProfileRules.enabledPrayerTypes(profile);

  Map<DateTime, Set<PrayerType>> _applyDateRules(
    Map<DateTime, Set<PrayerType>> available,
    Iterable<DateTime> dates,
    UserProfile profile,
  ) {
    final allowed = _profileAllowedPrayers(profile).toSet();
    final result = <DateTime, Set<PrayerType>>{};

    for (final date in dates) {
      final normalized = QazaDate.normalize(date);
      result[normalized] = _dateAllowed(normalized, profile)
          ? Set.unmodifiable(
              (available[normalized] ?? const <PrayerType>{})
                  .where(allowed.contains)
                  .toSet(),
            )
          : const <PrayerType>{};
    }

    return Map.unmodifiable(result);
  }

  bool _dateAllowed(DateTime date, UserProfile profile) {
    final normalized = QazaDate.normalize(date);
    if (normalized.isAfter(today)) return false;

    final start = ProfileRules.startPrayingDate(profile);
    if (start != null &&
        normalized.isBefore(QazaDate.normalize(start))) {
      return false;
    }

    return !normalized.isBefore(calendarFirstDate);
  }

  List<DateTime> _monthDates(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    return [
      for (var day = 1; day <= days; day++)
        DateTime(month.year, month.month, day),
    ];
  }

}