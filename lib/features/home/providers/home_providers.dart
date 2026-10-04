import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/repositories/qaza_activity_repository.dart';
import '../../../domain/services/qaza_activity_service.dart';
import '../../../domain/services/qaza_targeting_service.dart';
import '../../prayer_time/application/prayer_time_providers.dart';
import '../home_state.dart';

final homeNowProvider = Provider<DateTime>((ref) => DateTime.now());

DateTime homeLocalDateForInstant(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime homeLocalDayStartForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime homeLocalDayEndForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

DateTime homeCurrentWeekStartForDate(DateTime date) =>
    QazaActivityService.calendarWeekStartForDate(date);

DateTime homeCurrentWeekEndExclusiveForDate(DateTime date) =>
    QazaActivityService.calendarWeekEndExclusiveForDate(date);

final homeLocalDateProvider = Provider<DateTime>((ref) {
  return homeLocalDateForInstant(ref.watch(homeNowProvider));
});

final homeDailyProgressProvider =
    FutureProvider.autoDispose<HomeDailyProgress>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final today = ref.watch(homeLocalDateProvider);

  if (userId == null) {
    return HomeDailyProgress(completed: 0, target: target);
  }

  final start = homeLocalDayStartForDate(today);
  final end = homeLocalDayEndForDate(today);
  final completed = await ref.read(qazaServiceProvider).countCompletedBetween(
        userId: userId,
        from: start,
        to: end,
      );
  return HomeDailyProgress(completed: completed, target: target);
});

final qazaActivityServiceProvider = Provider<QazaActivityService>((ref) {
  final repository = ref.watch(qazaRepositoryProvider);
  if (repository is! QazaActivityRepository) {
    throw StateError('Local Qaza repository does not support activity history.');
  }
  final activityRepository = repository as QazaActivityRepository;
  return QazaActivityService(
    activityRepository,
    enabledPrayerTypes: ref.watch(enabledPrayerTypesProvider),
  );
});

class HomeDashboardActivity {
  const HomeDashboardActivity({
    required this.dailyProgress,
    required this.currentWeek,
    required this.dailyGoals,
  });

  final HomeDailyProgress dailyProgress;
  final QazaActivityPeriod currentWeek;
  final QazaActivityPeriod dailyGoals;
}

final homeDashboardActivityProvider =
    FutureProvider.autoDispose<HomeDashboardActivity>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final service = ref.read(qazaActivityServiceProvider);
  final enabled = service.enabledPrayerTypes;

  final currentWeek = homeCurrentWeekStartForDate(today);
  final dailyFrom = DateTime(today.year, today.month, today.day - 6);
  final queryFrom =
      dailyFrom.isBefore(currentWeek) ? dailyFrom : currentWeek;
  final weekEnd = homeCurrentWeekEndExclusiveForDate(today);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final queryToExclusive =
      weekEnd.isAfter(tomorrow) ? weekEnd : tomorrow;

  if (userId == null || enabled.isEmpty) {
    final emptyWeek = QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: currentWeek,
      toExclusive: weekEnd,
      today: today,
      dailyTarget: target,
      targetAvailable: true,
      enabledPrayerTypes: enabled,
    );
    final emptyDaily = QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: dailyFrom,
      toExclusive: tomorrow,
      today: today,
      dailyTarget: target,
      targetAvailable: true,
      enabledPrayerTypes: enabled,
    );
    return HomeDashboardActivity(
      dailyProgress: HomeDailyProgress(completed: 0, target: target),
      currentWeek: emptyWeek,
      dailyGoals: emptyDaily,
    );
  }

  final rows = await service.repository.getCompletedActivityRows(
    userId: userId,
    from: queryFrom,
    toExclusive: queryToExclusive,
    prayerTypes: enabled,
  );

  final weekPeriod = QazaActivityService.buildPeriodFromRows(
    rows: rows,
    from: currentWeek,
    toExclusive: weekEnd,
    today: today,
    dailyTarget: target,
    targetAvailable: true,
    enabledPrayerTypes: enabled,
  );
  final dailyPeriod = QazaActivityService.buildPeriodFromRows(
    rows: rows,
    from: dailyFrom,
    toExclusive: tomorrow,
    today: today,
    dailyTarget: target,
    targetAvailable: true,
    enabledPrayerTypes: enabled,
  );

  var completedToday = 0;
  for (final day in dailyPeriod.days) {
    if (day.date == today) {
      completedToday = day.completed;
      break;
    }
  }

  return HomeDashboardActivity(
    dailyProgress: HomeDailyProgress(
      completed: completedToday,
      target: target,
    ),
    currentWeek: weekPeriod,
    dailyGoals: dailyPeriod,
  );
});

final homeQazaActivityCurrentWeekProvider =
    FutureProvider.autoDispose<QazaActivityPeriod>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final from = homeCurrentWeekStartForDate(today);
  final toExclusive = homeCurrentWeekEndExclusiveForDate(today);

  if (userId == null) {
    return QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: from,
      toExclusive: toExclusive,
      today: today,
      dailyTarget: target,
      enabledPrayerTypes: ref.read(enabledPrayerTypesProvider),
    );
  }

  return ref.read(qazaActivityServiceProvider).buildCurrentCalendarWeek(
        userId: userId,
        today: today,
        dailyTarget: target,
      );
});


final homeQazaActivityDailyGoalsProvider =
    FutureProvider.autoDispose<QazaActivityPeriod>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final from = DateTime(today.year, today.month, today.day - 6);
  final toExclusive = DateTime(today.year, today.month, today.day + 1);

  if (userId == null) {
    return QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: from,
      toExclusive: toExclusive,
      today: today,
      dailyTarget: target,
      enabledPrayerTypes: ref.read(enabledPrayerTypesProvider),
    );
  }

  return ref.read(qazaActivityServiceProvider).buildPeriod(
        userId: userId,
        from: from,
        toExclusive: toExclusive,
        today: today,
        dailyTarget: target,
      );
});

final homeQazaActivityWeekProvider =
    FutureProvider.autoDispose.family<QazaActivityPeriod, DateTime>(
        (ref, selectedDate) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final selectedWeek =
      QazaActivityService.calendarWeekStartForDate(selectedDate);
  final currentWeek =
      QazaActivityService.calendarWeekStartForDate(today);
  final targetAvailable = selectedWeek == currentWeek;

  if (userId == null) {
    return QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: selectedWeek,
      toExclusive: DateTime(
        selectedWeek.year,
        selectedWeek.month,
        selectedWeek.day + 7,
      ),
      today: today,
      dailyTarget: target,
      targetAvailable: targetAvailable,
      enabledPrayerTypes: allPrayerTypes,
    );
  }

  return ref.read(qazaActivityServiceProvider).buildWeek(
        userId: userId,
        selectedDate: selectedWeek,
        today: today,
        dailyTarget: target,
        targetAvailable: targetAvailable,
        prayerTypes: allPrayerTypes,
      );
});

final homeQazaActivityMonthProvider =
    FutureProvider.autoDispose.family<QazaActivityPeriod, DateTime>(
        (ref, month) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final target = ref.watch(dailyQazaTargetProvider);
  final normalizedMonth = DateTime(month.year, month.month);
  final currentMonth = DateTime(today.year, today.month);
  final targetAvailable = normalizedMonth == currentMonth;

  if (userId == null) {
    return QazaActivityService.buildPeriodFromRows(
      rows: const <QazaActivityRow>[],
      from: normalizedMonth,
      toExclusive: DateTime(normalizedMonth.year, normalizedMonth.month + 1),
      today: today,
      dailyTarget: target,
      targetAvailable: targetAvailable,
      enabledPrayerTypes: allPrayerTypes,
    );
  }

  return ref.read(qazaActivityServiceProvider).buildMonth(
        userId: userId,
        month: normalizedMonth,
        today: today,
        dailyTarget: target,
        targetAvailable: targetAvailable,
        prayerTypes: allPrayerTypes,
      );
});

final homeQazaActivityYearProvider =
    FutureProvider.autoDispose.family<QazaActivityPeriod, DateTime>(
        (ref, year) async {
  final userId = ref.watch(activeUserIdProvider);
  final today = ref.watch(homeLocalDateProvider);
  final normalizedYear = DateTime(year.year);

  if (userId == null) {
    return QazaActivityService.buildYearFromRows(
      rows: const <QazaActivityRow>[],
      from: normalizedYear,
      toExclusive: DateTime(normalizedYear.year + 1, 1, 1),
      today: today,
      enabledPrayerTypes: allPrayerTypes,
    );
  }

  return ref.read(qazaActivityServiceProvider).buildYear(
        userId: userId,
        year: normalizedYear,
        today: today,
        prayerTypes: allPrayerTypes,
      );
});

class HomePrayerSelectionNotifier extends Notifier<HomePrayerSelectionState> {
  static const _modeStorageKey = 'qaza_home_completion_mode';
  static const _sequencePrayerStorageKey = 'qaza_home_auto_sequence_prayer';
  static const _selectedPrayerStorageKey = 'qaza_home_selected_prayer';

  Timer? _undoSnapshotTimer;
  HomePrayerSelectionState? _undoSnapshot;
  int _targetRevision = 0;
  int? _undoSnapshotRevision;

  @override
  HomePrayerSelectionState build() {
    Future<void>.microtask(_restore);
    return const HomePrayerSelectionState();
  }

  void _normalizeDisabledWitr() {
    final selectedPrayer = state.selectedPrayer == PrayerType.witr
        ? PrayerType.fajr
        : state.selectedPrayer;
    state = state.copyWith(
      autoSequencePrayer: PrayerType.fajr,
      selectedPrayer: selectedPrayer,
      clearSelectedPrayer: selectedPrayer == null,
    );
    _persistSequence(PrayerType.fajr);
    if (selectedPrayer != null) {
      _persistSelectedPrayer(selectedPrayer);
    } else {
      _clearPersistedSelectedPrayer();
    }
  }

  /// Explicitly selects a prayer and switches to sticky Prayer Selection.
  void selectPrayer(
    PrayerType prayer, {
    bool witrEnabled = true,
  }) {
    if (prayer == PrayerType.witr && !witrEnabled) return;
    state = state.copyWith(
      mode: HomePrayerSelectionMode.prayerSelection,
      selectedPrayer: prayer,
    );
    _targetRevision++;
    _persistMode(HomePrayerSelectionMode.prayerSelection);
    _persistSelectedPrayer(prayer);
  }

  /// Switches to Prayer Time while preserving the Auto Sequence cursor.
  void usePrayerTime() {
    state = state.copyWith(
      mode: HomePrayerSelectionMode.prayerTime,
      clearSelectedPrayer: true,
    );
    _targetRevision++;
    _persistMode(HomePrayerSelectionMode.prayerTime);
    _clearPersistedSelectedPrayer();
  }

  /// Switches to Auto Sequence while preserving the existing cursor.
  void useAutoSequence() {
    state = state.copyWith(
      mode: HomePrayerSelectionMode.autoSequence,
      clearSelectedPrayer: true,
    );
    _targetRevision++;
    _persistMode(HomePrayerSelectionMode.autoSequence);
    _clearPersistedSelectedPrayer();
  }

  /// Enters Prayer Selection with a valid sticky prayer.
  ///
  /// Reuses the previously selected prayer when available; otherwise Fajr is
  /// the deterministic initial selection.
  void usePrayerSelection({bool witrEnabled = true}) {
    final candidate = state.selectedPrayer ?? state.autoSequencePrayer;
    final prayer = !witrEnabled && candidate == PrayerType.witr
        ? PrayerType.fajr
        : candidate;
    state = state.copyWith(
      mode: HomePrayerSelectionMode.prayerSelection,
      selectedPrayer: prayer,
    );
    _targetRevision++;
    _persistMode(HomePrayerSelectionMode.prayerSelection);
    _persistSelectedPrayer(prayer);
  }

  void afterSuccessfulCompletion(
    PrayerType completedPrayer, {
    bool witrEnabled = true,
    bool targetWasAutoSequence = false,
  }) {
    _undoSnapshot ??= state;
    _undoSnapshotRevision ??= _targetRevision;
    _undoSnapshotTimer?.cancel();
    _undoSnapshotTimer = Timer(const Duration(seconds: 5), () {
      _undoSnapshot = null;
      _undoSnapshotRevision = null;
    });

    state = state.afterSuccessfulCompletion(
      completedPrayer,
      witrEnabled: witrEnabled,
      targetWasAutoSequence: targetWasAutoSequence,
    );
    _persistSequence(state.autoSequencePrayer);
  }

  void restoreAfterUndo() {
    final snapshot = _undoSnapshot;
    final snapshotRevision = _undoSnapshotRevision;
    if (snapshot == null) return;

    _undoSnapshotTimer?.cancel();
    _undoSnapshot = null;
    _undoSnapshotRevision = null;

    // A newer explicit user target change always wins over completion undo.
    if (snapshotRevision != _targetRevision) return;

    state = snapshot;
    _persistMode(snapshot.mode);
    _persistSequence(snapshot.autoSequencePrayer);
    if (snapshot.selectedPrayer != null) {
      _persistSelectedPrayer(snapshot.selectedPrayer!);
    }
  }

  Future<void> _restore() async {
    final restoreRevision = _targetRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeName = prefs.getString(_modeStorageKey);
      final sequenceName = prefs.getString(_sequencePrayerStorageKey);
      final selectedName = prefs.getString(_selectedPrayerStorageKey);
      final mode = HomePrayerSelectionMode.values.firstWhere(
        (value) => value.name == modeName,
        // Existing installations without saved state keep their legacy value;
        // genuinely new/uninitialized state defaults to Auto Sequence.
        orElse: () => HomePrayerSelectionMode.autoSequence,
      );
      final sequencePrayer = PrayerType.values.firstWhere(
        (value) => value.name == sequenceName,
        orElse: () => PrayerType.fajr,
      );
      var selectedPrayer = PrayerType.values.firstWhere(
        (value) => value.name == selectedName,
        orElse: () => PrayerType.fajr,
      );

      // Do not let an asynchronous restore overwrite an explicit choice made
      // while preferences were loading.
      if (restoreRevision != _targetRevision) return;

      // Preference restoration is intentionally independent from profile/DB
      // state. Witr eligibility is applied by the Home targeting layer when
      // it has the current profile available.
      state = HomePrayerSelectionState(
        mode: mode,
        selectedPrayer: mode == HomePrayerSelectionMode.prayerSelection
            ? selectedPrayer
            : null,
        autoSequencePrayer: sequencePrayer,
      );
    } catch (_) {
      // The default Auto Sequence/Fajr state is safe when preferences are unavailable.
    }
  }

  Future<void> _persistMode(HomePrayerSelectionMode mode) async {
    final revision = _targetRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision != _targetRevision) return;
      await prefs.setString(_modeStorageKey, mode.name);
    } catch (_) {}
  }

  Future<void> _persistSequence(PrayerType prayer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sequencePrayerStorageKey, prayer.name);
    } catch (_) {}
  }

  Future<void> _persistSelectedPrayer(PrayerType prayer) async {
    final revision = _targetRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision != _targetRevision) return;
      await prefs.setString(_selectedPrayerStorageKey, prayer.name);
    } catch (_) {}
  }

  Future<void> _clearPersistedSelectedPrayer() async {
    final revision = _targetRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision != _targetRevision) return;
      await prefs.remove(_selectedPrayerStorageKey);
    } catch (_) {}
  }
}

final homePrayerSelectionProvider =
    NotifierProvider<HomePrayerSelectionNotifier, HomePrayerSelectionState>(
  HomePrayerSelectionNotifier.new,
);

/// Pending-aware availability for the Home Prayer Selection grid.
///
/// Database access remains behind the existing aggregated progress provider;
/// this provider only derives which prayer targets have no pending Qaza.
final homePrayerSelectionDisabledPrayersProvider =
    Provider<Set<PrayerType>>((ref) {
  final summary = ref.watch(progressSummaryProvider).valueOrNull;
  if (summary == null) {
    // Unknown availability is never treated as actionable.
    return PrayerType.values.toSet();
  }

  return {
    for (final prayer in PrayerType.values)
      if ((summary.byPrayer[prayer]?.progress.pending ?? 0) <= 0) prayer,
  };
});

final homeFallbackPendingProvider =
    FutureProvider.autoDispose<QazaRecord?>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return null;
  return ref.read(qazaServiceProvider).oldestPendingOverall(userId: userId);
});

final homeSelectedPrayerProvider =
    Provider.autoDispose<HomeSelectedPrayerState>((ref) {
  final selection = ref.watch(homePrayerSelectionProvider);
  final tartibAsync = ref.watch(sahibAlTartibProvider);
  final tartib = tartibAsync.valueOrNull;
  final currentPrayer = ref.watch(currentQazaPrayerTypeProvider);

  // Sahib al-Tartib remains the final authority. Targeting modes never bypass
  // an active ordering requirement.
  if (tartibAsync.hasValue &&
      tartib?.requiresOrder == true &&
      tartib?.nextPrayer != null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: tartib!.nextPrayer,
      source: HomePrayerSelectionSource.sahibAlTartib,
    );
  }

  final target = switch (selection.mode) {
    HomePrayerSelectionMode.prayerTime => currentPrayer,
    HomePrayerSelectionMode.autoSequence => selection.autoSequencePrayer,
    HomePrayerSelectionMode.prayerSelection => selection.selectedPrayer,
  };

  final pendingAwareMode = selection.mode == HomePrayerSelectionMode.prayerTime ||
      selection.mode == HomePrayerSelectionMode.autoSequence;
  final summary = pendingAwareMode
      ? ref.watch(progressSummaryProvider).valueOrNull
      : null;
  final resolvedTarget =
      pendingAwareMode && target != null && summary != null
          ? const QazaTargetingService().resolveNextPendingPrayer(
              summary: summary,
              startPrayer: target,
              witrEnabled: ref.watch(effectiveWitrProvider),
            )
          : target;

  // An unavailable or zero-pending target is not actionable in the
  // pending-aware modes. Returning unavailable here lets the existing Home
  // all-completed/no-pending behavior take over without a false completion
  // action. Prayer Selection intentionally keeps its existing sticky behavior.
  if (resolvedTarget == null) {
    // Preserve the existing tartib-loading state for an unresolved Fard
    // target; pending-aware fallback must never turn an authority problem into
    // a generic no-target state.
    if (target != null &&
        target != PrayerType.witr &&
        (!tartibAsync.hasValue || tartib == null)) {
      return HomeSelectedPrayerState(
        mode: selection.mode,
        prayer: null,
        source: HomePrayerSelectionSource.tartibUnavailable,
      );
    }
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.unavailable,
    );
  }

  // Witr remains governed by the existing profile eligibility rule.
  if (resolvedTarget == PrayerType.witr &&
      !ref.watch(effectiveWitrProvider)) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.unavailable,
    );
  }

  // A Fard target still requires the existing Sahib al-Tartib result to be
  // known. We never use pending-aware fallback to bypass that authority.
  if (resolvedTarget != PrayerType.witr &&
      (!tartibAsync.hasValue || tartib == null)) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.tartibUnavailable,
    );
  }

  // Witr is independent of Sahib al-Tartib and remains actionable even while
  // the ordering check is temporarily unavailable.
  if (resolvedTarget == PrayerType.witr) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: resolvedTarget,
      source: switch (selection.mode) {
        HomePrayerSelectionMode.prayerTime =>
          HomePrayerSelectionSource.prayerTime,
        HomePrayerSelectionMode.autoSequence =>
          HomePrayerSelectionSource.autoSequence,
        HomePrayerSelectionMode.prayerSelection =>
          HomePrayerSelectionSource.prayerSelection,
      },
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: resolvedTarget,
    source: switch (selection.mode) {
      HomePrayerSelectionMode.prayerTime =>
        HomePrayerSelectionSource.prayerTime,
      HomePrayerSelectionMode.autoSequence =>
        HomePrayerSelectionSource.autoSequence,
      HomePrayerSelectionMode.prayerSelection =>
        HomePrayerSelectionSource.prayerSelection,
    },
  );
});
