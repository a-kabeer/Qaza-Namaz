// Centralized application state.
//
// Composition root for the Qaza Namaz app.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../data/data_transfer/qaza_data_transfer_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/drift_qaza_local_store.dart';
import '../data/local/qaza_local_store.dart';
import '../data/repositories/offline_first_qaza_repository.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/repositories/qaza_repository.dart';
import '../features/prayer_times/domain/prayer_schedule.dart';
import '../features/prayer_times/domain/prayer_times_models.dart';
import '../features/prayer_times/prayer_times_providers.dart';
import '../domain/services/qaza_service.dart';
import '../domain/services/sahib_al_tartib_service.dart';
import '../domain/services/qaza_undo_service.dart';
import '../domain/services/qaza_operation_service.dart';
import '../domain/repositories/qaza_operation_repository.dart';
import '../data/repositories/shared_preferences_qaza_operation_repository.dart';
import '../domain/services/profile_rules.dart';
import '../domain/services/qaza_plan_service.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../data/local/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => const SharedPreferencesUserProfileRepository(),
);

final userProfileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(userProfileRepositoryProvider).load(),
);

final effectiveWitrProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile == null ? true : ProfileRules.effectiveWitr(profile);
});

final qazaPlanServiceProvider = Provider<QazaPlanService>(
  (ref) => const QazaPlanService(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final qazaLocalStoreProvider = Provider<QazaLocalStore>((ref) {
  return DriftQazaLocalStore(database: ref.watch(appDatabaseProvider));
});

final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final repository = OfflineFirstQazaRepository(
    localStore: ref.watch(qazaLocalStoreProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  );
  ref.listen<String?>(
    activeUserIdProvider,
    (_, next) => repository.setActiveUser(next),
    fireImmediately: true,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final qazaPrayerTimeBlockedResolverProvider =
    Provider<QazaPrayerTimeBlockedResolver>((ref) {
  final prayerTimesRepository = ref.watch(prayerTimesRepositoryProvider);
  final clock = ref.watch(prayerTimesClockProvider);

  return ({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
  }) async {
    final requestedDates =
        dates.map((date) => DateTime(date.year, date.month, date.day)).toSet();
    final requestedPrayers = prayerTypes.toSet();
    if (requestedDates.isEmpty || requestedPrayers.isEmpty) {
      return const <QazaPrayerKey>{};
    }

    final location = await prayerTimesRepository.getSavedLocation();
    final timezone = location?.timezone;
    if (location == null || timezone == null || timezone.isEmpty) {
      return const <QazaPrayerKey>{};
    }

    final instant = clock.now();
    final localNow = PrayerSchedule.now(timezone, instant: instant);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    if (!requestedDates.contains(today)) return const <QazaPrayerKey>{};

    final settings = await prayerTimesRepository.getSavedSettings();
    final todaySchedule = await prayerTimesRepository.getPrayerTimes(
      latitude: location.latitude,
      longitude: location.longitude,
      date: today,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
      timezone: timezone,
    );

    PrayerDay? tomorrowSchedule;
    if (requestedPrayers.contains(PrayerType.isha) ||
        requestedPrayers.contains(PrayerType.witr)) {
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      tomorrowSchedule = await prayerTimesRepository.getPrayerTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        date: tomorrow,
        method: settings.calculationMethod,
        asrMethod: settings.asrMethod,
        timezone: timezone,
      );
    }

    DateTime? waqtEnd(PrayerType prayer) => switch (prayer) {
          PrayerType.fajr =>
            PrayerSchedule.moment(todaySchedule, PrayerName.sunrise),
          PrayerType.zuhr =>
            PrayerSchedule.moment(todaySchedule, PrayerName.asr),
          PrayerType.asr =>
            PrayerSchedule.moment(todaySchedule, PrayerName.maghrib),
          PrayerType.maghrib =>
            PrayerSchedule.moment(todaySchedule, PrayerName.isha),
          PrayerType.isha => tomorrowSchedule == null
              ? null
              : PrayerSchedule.moment(tomorrowSchedule, PrayerName.fajr),
          PrayerType.witr => tomorrowSchedule == null
              ? null
              : PrayerSchedule.moment(tomorrowSchedule, PrayerName.fajr),
        };

    final blocked = <QazaPrayerKey>{};
    for (final prayer in requestedPrayers) {
      final end = waqtEnd(prayer);
      if (end != null && localNow.isBefore(end)) {
        blocked.add(QazaPrayerKey(
          userId: userId,
          date: today,
          prayerType: prayer,
        ));
      }
    }
    return blocked;
  };
});

final diagnosticsProvider = Provider<DiagnosticsService>(
  (ref) => kReleaseMode ? PersistentDiagnostics() : const DebugDiagnostics(),
);

final qazaServiceProvider = Provider<QazaService>((ref) => QazaService(
      ref.watch(qazaRepositoryProvider),
      witrInclusionResolver: () => ref.read(effectiveWitrProvider),
      diagnostics: ref.watch(diagnosticsProvider),
      prayerTimeBlockedResolver: ({
        required userId,
        required dates,
        required prayerTypes,
      }) =>
          ref.read(qazaPrayerTimeBlockedResolverProvider)(
        userId: userId,
        dates: dates,
        prayerTypes: prayerTypes,
      ),
    ));

final sahibAlTartibProvider =
    FutureProvider.autoDispose<SahibAlTartibState>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    return Future.value(
      const SahibAlTartibState(
        pendingFarzCount: 0,
        requiresOrder: false,
        nextPending: null,
      ),
    );
  }
  return ref.read(qazaServiceProvider).sahibAlTartibState(userId: userId);
});

final qazaOperationRepositoryProvider =
    Provider<QazaOperationRepository>(
  (ref) => SharedPreferencesQazaOperationRepository(),
);

final qazaOperationServiceProvider = Provider<QazaOperationService>(
  (ref) => QazaOperationService(ref.watch(qazaOperationRepositoryProvider)),
);

final qazaUndoManagerProvider = Provider<QazaUndoManager>(
  (ref) => QazaUndoManager(),
);

final qazaDataTransferServiceProvider = Provider<QazaDataTransferService>(
  (ref) => QazaDataTransferService(ref.watch(qazaRepositoryProvider)),
);

/// The ledger belongs to this device's local profile. The legacy identifier
/// remains stable so existing installed data stays visible after the auth
/// system is removed.
final activeUserIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile == null ? null : UserProfile.localLedgerUserId;
});

final requiredUserIdProvider = Provider<String>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    throw StateError('A completed local profile is required.');
  }
  return userId;
});

final progressSummaryProvider =
    FutureProvider.autoDispose<QazaProgressSummary>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(QazaProgressSummary.empty());
  return ref.read(qazaServiceProvider).getProgressSummary(userId: userId);
});

final oldestPendingProvider =
    FutureProvider.autoDispose.family<QazaRecord?, PrayerType>((ref, prayer) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref
      .read(qazaServiceProvider)
      .oldestPending(userId: userId, prayerType: prayer);
});

final latestPendingProvider =
    FutureProvider.autoDispose.family<QazaRecord?, PrayerType>((ref, prayer) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref
      .read(qazaServiceProvider)
      .latestPending(userId: userId, prayerType: prayer);
});

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const String storageKey = 'qaza_theme_mode';

  @override
  AppThemeMode build() {
    Future.microtask(restore);
    return AppThemeMode.system;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (stored == null) return;
      state = AppThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => AppThemeMode.system,
      );
    } catch (_) {}
  }

  void set(AppThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  Future<void> _persist(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const String storageKey = 'qaza_locale';
  static const Locale fallback = Locale('en');

  @override
  Locale build() {
    Future.microtask(restore);
    return fallback;
  }

  static List<Locale> get supported => AppLocalizations.supportedLocales;

  static Locale? resolve(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return null;
    for (final locale in supported) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolved = resolve(prefs.getString(storageKey));
      if (resolved != null) state = resolved;
    } catch (_) {}
  }

  void set(Locale locale) {
    final resolved = resolve(locale.languageCode);
    if (resolved == null) return;
    state = resolved;
    _persist(resolved);
  }

  Future<void> _persist(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, locale.languageCode);
    } catch (_) {}
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
