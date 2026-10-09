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
import '../core/widgets/app_snackbar.dart';
import '../l10n/app_localizations.dart';
import '../data/data_transfer/local_backup_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/drift_qaza_local_store.dart';
import '../data/local/account_local_store.dart';
import '../data/local/account_scoped_user_profile_repository.dart';
import '../data/local/account_scoped_qaza_plan_revision_repository.dart';
import '../data/local/onboarding_commit_repository.dart';
import '../domain/repositories/onboarding_commit_repository.dart';
import '../features/account/account_session_manager.dart';
import '../data/local/qaza_local_store.dart';
import '../data/local/database/qaza_addition_repository.dart';
import '../data/repositories/offline_first_qaza_repository.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/entities/qaza_addition.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/qaza_plan_revision_repository.dart';
import '../domain/repositories/qaza_profile_plan_mutation_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../domain/repositories/qaza_addition_repository.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../domain/services/cloud_sync_contracts.dart';
import '../domain/services/profile_qaza_plan_reconciliation_service.dart';
import '../domain/services/profile_rules.dart';
import '../domain/services/qaza_plan_service.dart';
import '../domain/services/qaza_service.dart';
import '../domain/services/qaza_addition_service.dart';
import '../domain/services/qaza_undo_service.dart';
import '../domain/services/save_profile_use_case.dart';

final appSnackbarServiceProvider = Provider<AppSnackbarService>(
  (_) => AppSnackbarService(messengerKey: appScaffoldMessengerKey),
);

/// Optional capabilities default to unavailable in the offline-only target.
/// Cloud-enabled hosts override both providers from their composition root.
final cloudAccountProvider = Provider<CloudAccountProvider>(
  (ref) => const UnsupportedCloudAccountProvider(),
);

final cloudSyncProvider = Provider<CloudSyncProvider>(
  (ref) => const UnsupportedCloudSyncProvider(),
);

/// Prefix for assets/fonts owned by this package when embedded as a dependency.
/// Null in the standalone offline app; the optional host sets `qaza_namaz`.
final packageAssetNamespaceProvider = Provider<String?>((ref) => null);

final accountLocalStoreProvider = Provider<AccountLocalStore>((ref) {
  return AccountLocalStore(database: ref.watch(appDatabaseProvider));
});

final activeLocalAccountIdStateProvider = StateProvider<String?>((ref) => null);

final activeUserIdProvider = Provider<String?>((ref) {
  return ref.watch(activeLocalAccountIdStateProvider);
});

final accountSessionManagerProvider =
    ChangeNotifierProvider<AccountSessionManager>((ref) {
  final manager = AccountSessionManager(
    accountStore: ref.watch(accountLocalStoreProvider),
    onActiveLocalAccountChanged: (id) {
      ref.read(activeLocalAccountIdStateProvider.notifier).state = id;
    },
  );
  return manager;
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return AccountScopedUserProfileRepository(
    store: ref.watch(accountLocalStoreProvider),
    activeAccountId: () => ref.read(activeUserIdProvider),
  );
});

/// A null profile is a legitimate first-time-user state. Repository/provider
/// failures intentionally propagate as AsyncError so StartupGate can route them
/// to a retryable storage boundary instead of onboarding.
final userProfileProvider = FutureProvider<UserProfile?>((ref) {
  ref.watch(activeUserIdProvider);
  return ref.read(userProfileRepositoryProvider).load();
});

/// Single source of truth for the user's daily Qaza target.
///
/// The preference belongs to [UserProfile]. Home and any future consumers
/// read this derived provider rather than maintaining feature-specific state.
final dailyQazaTargetProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.dailyQazaTarget ?? UserProfile.defaultDailyQazaTarget;
});

final effectiveWitrProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile == null ? true : ProfileRules.effectiveWitr(profile);
});

final enabledPrayerTypesProvider = Provider<List<PrayerType>>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return List<PrayerType>.of(allPrayerTypes);
  return ProfileRules.enabledPrayerTypes(profile);
});

final qazaPlanServiceProvider = Provider<QazaPlanService>(
  (ref) => const QazaPlanService(),
);

final qazaPlanRevisionRepositoryProvider = Provider<QazaPlanRevisionRepository>(
  (ref) => AccountScopedQazaPlanRevisionRepository(
    ref.watch(accountLocalStoreProvider),
  ),
);

final onboardingCommitRepositoryProvider =
    Provider<OnboardingCommitRepository>((ref) {
  return AccountLocalOnboardingCommitRepository(
    ref.watch(accountLocalStoreProvider),
  );
});

final profileQazaPlanReconciliationServiceProvider =
    Provider<ProfileQazaPlanReconciliationService>((ref) {
  return ProfileQazaPlanReconciliationService(
    planService: ref.watch(qazaPlanServiceProvider),
    qazaService: ref.watch(qazaServiceProvider),
    revisionRepository: ref.watch(qazaPlanRevisionRepositoryProvider),
    mutationRepository: ref.watch(qazaProfilePlanMutationRepositoryProvider),
  );
});

final saveProfileUseCaseProvider = Provider<SaveProfileUseCase>((ref) {
  return SaveProfileUseCase(
    profileRepository: ref.watch(userProfileRepositoryProvider),
    reconciliationService:
        ref.watch(profileQazaPlanReconciliationServiceProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final cloudSetupChoiceCompleteProvider = FutureProvider<bool>((ref) {
  return ref.watch(appDatabaseProvider).isCloudSetupChoiceComplete();
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

final qazaProfilePlanMutationRepositoryProvider =
    Provider<QazaProfilePlanMutationRepository>((ref) {
  final repository = ref.watch(qazaRepositoryProvider);
  if (repository is! QazaProfilePlanMutationRepository) {
    throw StateError(
      'The active Qaza repository does not support profile-plan mutations.',
    );
  }
  return repository as QazaProfilePlanMutationRepository;
});

final diagnosticsProvider = Provider<DiagnosticsService>(
  (ref) => kReleaseMode ? const NoopDiagnostics() : const DebugDiagnostics(),
);

final qazaServiceProvider = Provider<QazaService>(
  (ref) => QazaService(
    ref.watch(qazaRepositoryProvider),
    witrInclusionResolver: () => ref.read(effectiveWitrProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  ),
);

final qazaAdditionRepositoryProvider = Provider<QazaAdditionRepository>(
  (ref) => DriftQazaAdditionRepository(ref.watch(appDatabaseProvider)),
);

final qazaAdditionServiceProvider = Provider<QazaAdditionService>(
  (ref) => QazaAdditionService(
    qazaService: ref.watch(qazaServiceProvider),
    repository: ref.watch(qazaAdditionRepositoryProvider),
  ),
);

final qazaAdditionDetailProvider =
    FutureProvider.autoDispose.family<QazaAdditionDetail?, String>(
  (ref, additionId) {
    final userId = ref.watch(activeUserIdProvider);
    if (userId == null) return Future.value(null);
    return ref.read(qazaAdditionRepositoryProvider).getAdditionDetail(
          userId: userId,
          additionId: additionId,
        );
  },
);

final qazaUndoManagerProvider = Provider<QazaUndoManager>(
  (ref) => QazaUndoManager(),
);

final localBackupServiceProvider = Provider<LocalBackupService>(
  (ref) => LocalBackupService(ref.watch(appDatabaseProvider)),
);

enum AppRoute { onboarding, home }

class AppRouteNotifier extends AsyncNotifier<AppRoute> {
  @override
  Future<AppRoute> build() async {
    final completed =
        await ref.read(appDatabaseProvider).isOnboardingCompleted();
    return completed ? AppRoute.home : AppRoute.onboarding;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final appRouteProvider =
    AsyncNotifierProvider<AppRouteNotifier, AppRoute>(AppRouteNotifier.new);

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
  static const String storageKey = 'language_code';
  static const Locale fallback = Locale('en');

  @override
  Locale build() {
    Future.microtask(restore);
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return resolve(systemLocale.languageCode) ?? fallback;
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

  void preview(Locale locale) {
    final resolved = resolve(locale.languageCode);
    if (resolved == null) return;
    state = resolved;
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
