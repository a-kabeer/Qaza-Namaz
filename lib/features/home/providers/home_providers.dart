import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_record.dart';
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

class HomePrayerSelectionNotifier extends Notifier<HomePrayerSelectionState> {
  static const _modeStorageKey = 'qaza_home_completion_mode';
  static const _sequencePrayerStorageKey = 'qaza_home_auto_sequence_prayer';

  @override
  HomePrayerSelectionState build() {
    Future<void>.microtask(_restore);
    return const HomePrayerSelectionState();
  }

  void selectPrayer(PrayerType prayer) {
    state = state.copyWith(manualPrayer: prayer);
  }

  void usePrayerTime() {
    state = const HomePrayerSelectionState(
      mode: HomePrayerSelectionMode.prayerTime,
    );
    _persistMode(HomePrayerSelectionMode.prayerTime);
  }

  void useAutoSequence() {
    state = state.copyWith(
      mode: HomePrayerSelectionMode.autoSequence,
      clearManualPrayer: true,
    );
    _persistMode(HomePrayerSelectionMode.autoSequence);
  }

  void afterSuccessfulCompletion(PrayerType completedPrayer) {
    state = state.afterSuccessfulCompletion(completedPrayer);
    _persistSequence(state.autoSequencePrayer);
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeName = prefs.getString(_modeStorageKey);
      final sequenceName = prefs.getString(_sequencePrayerStorageKey);
      final mode = HomePrayerSelectionMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => HomePrayerSelectionMode.prayerTime,
      );
      final sequencePrayer = PrayerType.values.firstWhere(
        (value) => value.name == sequenceName,
        orElse: () => PrayerType.fajr,
      );
      state = state.copyWith(
        mode: mode,
        autoSequencePrayer: sequencePrayer,
        clearManualPrayer: true,
      );
    } catch (_) {
      // The default Prayer Time mode is safe when preferences are unavailable.
    }
  }

  Future<void> _persistMode(HomePrayerSelectionMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeStorageKey, mode.name);
    } catch (_) {}
  }

  Future<void> _persistSequence(PrayerType prayer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sequencePrayerStorageKey, prayer.name);
    } catch (_) {}
  }
}

final homePrayerSelectionProvider =
    NotifierProvider<HomePrayerSelectionNotifier, HomePrayerSelectionState>(
  HomePrayerSelectionNotifier.new,
);

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

  final target = selection.manualPrayer ??
      switch (selection.mode) {
        HomePrayerSelectionMode.prayerTime =>
          currentPrayer,
        HomePrayerSelectionMode.autoSequence => selection.autoSequencePrayer,
      };

  // Witr is independent of Sahib al-Tartib and remains actionable even while
  // the ordering check is temporarily unavailable.
  if (target == PrayerType.witr) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: target,
      source: selection.hasManualOverride
          ? HomePrayerSelectionSource.manual
          : selection.mode == HomePrayerSelectionMode.prayerTime
              ? HomePrayerSelectionSource.prayerTime
              : HomePrayerSelectionSource.autoSequence,
    );
  }

  if (!tartibAsync.hasValue || tartib == null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.tartibUnavailable,
    );
  }

  if (target == null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.unavailable,
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: target,
    source: selection.hasManualOverride
        ? HomePrayerSelectionSource.manual
        : selection.mode == HomePrayerSelectionMode.prayerTime
            ? HomePrayerSelectionSource.prayerTime
            : HomePrayerSelectionSource.autoSequence,
  );
});
