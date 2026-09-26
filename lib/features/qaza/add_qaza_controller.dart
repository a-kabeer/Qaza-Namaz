import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/user_profile.dart';
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
    this.calendarAvailability = const <DateTime, Set<PrayerType>>{},
    this.calendarLoading = true,
    this.analysisLoading = false,
    this.analysis = AddQazaAnalysis.empty,
    this.error,
  });

  final DateSelectionMode mode;
  final List<DateTime> selectedDates;
  final Set<PrayerType> selectedPrayers;
  final Map<DateTime, Set<PrayerType>> calendarAvailability;
  final bool calendarLoading;
  final bool analysisLoading;
  final AddQazaAnalysis analysis;
  final Object? error;

  bool get canReview =>
      selectedDates.isNotEmpty &&
      selectedPrayers.isNotEmpty &&
      !analysisLoading;

  AddQazaState copyWith({
    DateSelectionMode? mode,
    List<DateTime>? selectedDates,
    Set<PrayerType>? selectedPrayers,
    Map<DateTime, Set<PrayerType>>? calendarAvailability,
    bool? calendarLoading,
    bool? analysisLoading,
    AddQazaAnalysis? analysis,
    Object? error,
    bool clearError = false,
  }) =>
      AddQazaState(
        mode: mode ?? this.mode,
        selectedDates: selectedDates ?? this.selectedDates,
        selectedPrayers: selectedPrayers ?? this.selectedPrayers,
        calendarAvailability:
            calendarAvailability ?? this.calendarAvailability,
        calendarLoading: calendarLoading ?? this.calendarLoading,
        analysisLoading: analysisLoading ?? this.analysisLoading,
        analysis: analysis ?? this.analysis,
        error: clearError ? null : error ?? this.error,
      );
}

final addQazaControllerProvider =
    AutoDisposeNotifierProvider<AddQazaController, AddQazaState>(
  AddQazaController.new,
);

class AddQazaController extends AutoDisposeNotifier<AddQazaState> {
  DateTime? _visibleMonth;
  bool _disposed = false;
  int _calendarRequest = 0;
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
    ref.onDispose(
      () => ref.read(calendarControllerProvider.notifier).clear(),
    );

    final initialCalendarState = ref.read(calendarControllerProvider);
    Future.microtask(() {
      if (!_disposed) return;
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

  void setMode(DateSelectionMode mode) {
    ref.read(calendarControllerProvider.notifier).setSelectionMode(mode);
  }

  void togglePrayer(PrayerType prayer) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (prayer == PrayerType.witr &&
        profile != null &&
        !ProfileRules.effectiveWitr(profile)) {
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

      if (!_disposed || request != _calendarRequest) return;

      state = state.copyWith(
        calendarAvailability: _applyDateRules(
          available,
          dates,
          profile,
        ),
        calendarLoading: false,
      );
    } catch (error) {
      if (!_disposed || request != _calendarRequest) return;
      state = state.copyWith(
        calendarLoading: false,
        error: error,
      );
    }
  }

  Future<Map<DateTime, Set<PrayerType>>> resolveAvailability(
    DateTime start,
    DateTime end,
  ) async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return const <DateTime, Set<PrayerType>>{};

    final dates = _dateRange(start, end);
    final available =
        await ref.read(qazaServiceProvider).getAvailablePrayersByDate(
              userId: ref.read(requiredUserIdProvider),
              dates: dates,
              prayerTypes: _profileAllowedPrayers(profile),
            );

    return _applyDateRules(available, dates, profile);
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
          return a.key.prayerType.index.compareTo(b.key.prayerType.index);
        });

      final analysis = AddQazaAnalysis(
        items: List.unmodifiable(items),
      );

      if (!_disposed || request != _analysisRequest) return analysis;

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
    if (profile == null || !_disposed) return;

    final selected = Set<PrayerType>.of(state.selectedPrayers);
    if (!ProfileRules.effectiveWitr(profile)) {
      selected.remove(PrayerType.witr);
    }

    state = state.copyWith(
      selectedPrayers: Set.unmodifiable(selected),
    );

    final visible = _visibleMonth;
    if (visible != null) refreshCalendarMonth(visible);
    _refreshAnalysis();
  }

  void _onCalendarSelectionChanged(CalendarSelectionState next) {
    final dates =
        next.datesForStorage.map(QazaDate.normalize).toList(growable: false);

    state = state.copyWith(
      mode: next.selectionMode,
      selectedDates: List.unmodifiable(dates),
      clearError: true,
    );
    _refreshAnalysis();
  }

  Future<void> _refreshAnalysis() async {
    try {
      await refreshAnalysis();
    } catch (_) {}
  }

  List<PrayerType> _profileAllowedPrayers(UserProfile profile) => [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        if (ProfileRules.effectiveWitr(profile)) PrayerType.witr,
      ];

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

  List<DateTime> _dateRange(DateTime start, DateTime end) {
    final normalizedStart = QazaDate.normalize(start);
    final normalizedEnd = QazaDate.normalize(end);
    if (normalizedEnd.isBefore(normalizedStart)) {
      return const <DateTime>[];
    }

    final dates = <DateTime>[];
    for (var date = normalizedStart;
        !date.isAfter(normalizedEnd);
        date = DateTime(date.year, date.month, date.day + 1)) {
      dates.add(date);
    }
    return dates;
  }
}