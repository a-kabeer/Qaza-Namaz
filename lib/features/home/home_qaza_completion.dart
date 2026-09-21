import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../prayer_times/domain/prayer_schedule.dart';
import '../prayer_times/domain/prayer_times_models.dart';
import '../prayer_times/prayer_times_providers.dart';
import '../prayer_times/presentation/prayer_times_controller.dart';

enum HomePrayerSelectionMode {
  automatic,
  manual,
}

class HomePrayerSelectionState {
  const HomePrayerSelectionState({
    this.mode = HomePrayerSelectionMode.automatic,
    this.manualPrayer,
  });

  final HomePrayerSelectionMode mode;
  final PrayerType? manualPrayer;

  PrayerType? get selectedPrayer =>
      mode == HomePrayerSelectionMode.manual ? manualPrayer : null;

  HomePrayerSelectionState copyWith({
    HomePrayerSelectionMode? mode,
    PrayerType? manualPrayer,
    bool clearManualPrayer = false,
  }) {
    return HomePrayerSelectionState(
      mode: mode ?? this.mode,
      manualPrayer:
          clearManualPrayer ? null : (manualPrayer ?? this.manualPrayer),
    );
  }
}

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

final homePrayerSelectionProvider = NotifierProvider<
    HomePrayerSelectionNotifier, HomePrayerSelectionState>(
  HomePrayerSelectionNotifier.new,
);

/// The prayer period suggested by the existing Prayer Time module.
///
/// Witr deliberately is not inferred because the Prayer Time API does not
/// expose Witr as a cycle boundary. Witr remains a manual Home selection.
PrayerType? currentHomePrayerForSchedule({
  required PrayerDay today,
  PrayerDay? tomorrow,
  required DateTime now,
}) {
  final result = PrayerSchedule.evaluate(
    today: today,
    tomorrow: tomorrow,
    nowOverride: now,
  );

  return switch (result.current) {
    PrayerName.fajr => PrayerType.fajr,
    PrayerName.dhuhr => PrayerType.zuhr,
    PrayerName.asr => PrayerType.asr,
    PrayerName.maghrib => PrayerType.maghrib,
    PrayerName.isha => PrayerType.isha,
    PrayerName.sunrise || null => null,
  };
}

class HomeCurrentPrayerState {
  const HomeCurrentPrayerState({this.prayer});

  final PrayerType? prayer;
}

class HomeCurrentPrayerNotifier extends Notifier<HomeCurrentPrayerState> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  HomeCurrentPrayerState build() {
    final prayerTimesState = ref.watch(prayerTimesControllerProvider);

    _timer?.cancel();
    _lifecycle?.dispose();

    final initial = _resolve(prayerTimesState, DateTime.now());

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _tick(),
    );
    _lifecycle = AppLifecycleListener(
      onResume: _tick,
    );

    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });

    return HomeCurrentPrayerState(prayer: initial);
  }

  void _tick() {
    state = HomeCurrentPrayerState(
      prayer: _resolve(
        ref.read(prayerTimesControllerProvider),
        DateTime.now(),
      ),
    );
  }

  PrayerType? _resolve(
    PrayerTimesState state,
    DateTime now,
  ) {
    final today = state.today;
    if (!state.hasData || today == null) return null;

    return currentHomePrayerForSchedule(
      today: today,
      tomorrow: state.tomorrow,
      now: now,
    );
  }
}

final homeCurrentPrayerProvider =
    NotifierProvider<HomeCurrentPrayerNotifier, HomeCurrentPrayerState>(
  HomeCurrentPrayerNotifier.new,
);

class HomeSelectedPrayerState {
  const HomeSelectedPrayerState({
    required this.mode,
    this.prayer,
  });

  final HomePrayerSelectionMode mode;
  final PrayerType? prayer;
}

/// The actual prayer used by the Home completion card.
///
/// Automatic mode follows Prayer Time. Manual mode follows the selected chip
/// until the user switches back to Auto.
final homeSelectedPrayerProvider = Provider<HomeSelectedPrayerState>((ref) {
  final selection = ref.watch(homePrayerSelectionProvider);
  if (selection.mode == HomePrayerSelectionMode.manual) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: selection.manualPrayer,
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: ref.watch(homeCurrentPrayerProvider).prayer,
  );
});
