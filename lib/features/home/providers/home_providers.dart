import 'dart:async';
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
  @override
  HomePrayerSelectionState build() => const HomePrayerSelectionState();

  void selectPrayer(PrayerType prayer) {
    state = HomePrayerSelectionState(
      mode: HomePrayerSelectionMode.manual,
      manualPrayer: prayer,
    );
  }

  void useAutomatic() {
    state = const HomePrayerSelectionState(
      mode: HomePrayerSelectionMode.automatic,
    );
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

  // Sahib al-Tartib is an actionable domain constraint, not merely a menu
  // filter. When it becomes active, it must override a stale manual choice so
  // Home never displays a prayer that the completion layer will reject.
  if (tartibAsync.hasValue &&
      tartib?.requiresOrder == true &&
      tartib?.nextPrayer != null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: tartib!.nextPrayer,
      source: HomePrayerSelectionSource.sahibAlTartib,
    );
  }

  if (!tartibAsync.hasValue || tartib == null) {
    // Witr remains independently actionable while Fard ordering is being
    // resolved. A previously selected Fard must not look actionable while the
    // tartib decision is still loading or unavailable.
    if (selection.mode == HomePrayerSelectionMode.manual &&
        selection.manualPrayer == PrayerType.witr) {
      return HomeSelectedPrayerState(
        mode: selection.mode,
        prayer: PrayerType.witr,
        source: HomePrayerSelectionSource.manual,
      );
    }

    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.tartibUnavailable,
    );
  }

  if (selection.mode == HomePrayerSelectionMode.manual) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: selection.manualPrayer,
      source: HomePrayerSelectionSource.manual,
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: null,
    source: HomePrayerSelectionSource.unavailable,
  );
});
