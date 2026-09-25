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

final diagnosticsProvider = Provider<DiagnosticsService>(
  (ref) => kReleaseMode ? PersistentDiagnostics() : const DebugDiagnostics(),
);

final qazaServiceProvider = Provider<QazaService>((ref) => QazaService(
      ref.watch(qazaRepositoryProvider),
      witrInclusionResolver: () => ref.read(effectiveWitrProvider),
      diagnostics: ref.watch(diagnosticsProvider),
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
