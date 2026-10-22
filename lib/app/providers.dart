// Centralized application state.
//
// Composition root for the Qaza Namaz app.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/diagnostics/diagnostics.dart';
import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';
import '../l10n/app_localizations.dart';
import '../data/data_transfer/local_backup_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/database/database_manager.dart';
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
import '../features/home/home_state.dart';
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

/// Startup values loaded before runApp to avoid a one-frame default-state flash.
final initialThemeModeProvider =
    Provider<AppThemeMode>((ref) => AppThemeMode.system);

final initialPrimaryColorProvider =
    Provider<AppPrimaryColor>((ref) => AppPrimaryColor.teal);

final initialHomePrayerSelectionProvider = Provider<HomePrayerSelectionState>(
  (ref) => const HomePrayerSelectionState(),
);

Future<(AppThemeMode, AppPrimaryColor)> loadInitialAppearance() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final storedMode = preferences.getString(ThemeModeNotifier.storageKey);
    final storedColor = preferences.getString(PrimaryColorNotifier.storageKey);
    final mode = AppThemeMode.values.firstWhere(
      (value) => value.name == storedMode,
      orElse: () => AppThemeMode.system,
    );
    final color = AppPrimaryColor.values.firstWhere(
      (value) => value.name == storedColor,
      orElse: () => AppPrimaryColor.teal,
    );
    return (mode, color);
  } catch (_) {
    return (AppThemeMode.system, AppPrimaryColor.teal);
  }
}

Future<HomePrayerSelectionState> loadInitialHomePrayerSelection() async {
  final databaseManager = DatabaseManager();
  final database = databaseManager.controlDatabase;
  try {
    final rows = await database
        .customSelect(
          "SELECT key, value FROM meta_store WHERE key IN ("
          "'qaza_home_completion_mode', "
          "'qaza_home_auto_sequence_prayer', "
          "'qaza_home_selected_prayer')",
        )
        .get();
    final values = <String, String>{
      for (final row in rows)
        row.read<String>('key'): row.read<String>('value'),
    };
    final mode = HomePrayerSelectionMode.values.firstWhere(
      (value) => value.name == values['qaza_home_completion_mode'],
      orElse: () => HomePrayerSelectionMode.autoSequence,
    );
    final autoSequencePrayer = PrayerType.values.firstWhere(
      (value) => value.name == values['qaza_home_auto_sequence_prayer'],
      orElse: () => PrayerType.fajr,
    );
    final selectedPrayer = PrayerType.values.firstWhere(
      (value) => value.name == values['qaza_home_selected_prayer'],
      orElse: () => PrayerType.fajr,
    );
    return HomePrayerSelectionState(
      mode: mode,
      selectedPrayer: mode == HomePrayerSelectionMode.prayerSelection
          ? selectedPrayer
          : null,
      autoSequencePrayer: autoSequencePrayer,
    );
  } catch (_) {
    return const HomePrayerSelectionState();
  } finally {
    await databaseManager.close();
  }
}

/// Optional capabilities default to unavailable in the offline-only target.
/// Cloud-enabled hosts override both providers from their composition root.
final cloudAccountProvider = Provider<CloudAccountProvider>(
  (ref) => const UnsupportedCloudAccountProvider(),
);

/// Loads the optional cloud account snapshot for onboarding. The implementation
/// may inspect a resolved account and cached identity, but must never prompt for
/// authentication; interactive sign-in is only initiated by an explicit action.
final cloudAccountStartupRestoreProvider =
    FutureProvider<CloudAccountSnapshot>((ref) {
  final account = ref.watch(cloudAccountProvider);
  if (!account.isSupported) {
    return Future.value(const CloudAccountSnapshot.unavailable());
  }
  return account.restore();
});

/// True after an explicit account-choice flow already activated the selected
/// workspace during this process.
final startupWorkspaceRestoreSatisfiedProvider =
    StateProvider<bool>((ref) => false);

/// Restores the active cloud identity before routing to account-specific UI.
/// StartupGate keeps the splash visible until workspace activation completes,
/// preventing stale Guest onboarding/profile content from flashing on screen.
final startupAccountWorkspaceRestoreProvider =
    FutureProvider<void>((ref) async {
  if (ref.read(startupWorkspaceRestoreSatisfiedProvider)) return;

  final cloudAccount = ref.watch(cloudAccountProvider);
  final session = ref.read(accountSessionManagerProvider);
  if (cloudAccount.isSupported) {
    final snapshot = await cloudAccount.restore();
    final accountId = snapshot.accountId?.trim();
    if (accountId != null &&
        accountId.isNotEmpty &&
        snapshot.status != CloudAccountStatus.disconnected &&
        snapshot.status != CloudAccountStatus.unavailable) {
      // A verified Google identity selects its own workspace. When no Google
      // identity is connected, preserve the persisted local workspace rather
      // than resetting every returning Guest to the legacy fixed workspace.
      await session.activateGoogleAccount(accountId);
    }
    // Disconnected, offline, and unavailable cloud states do not prove that
    // a local workspace should be replaced or cleared.
  }

  // AccountSessionManager.initialize() starts from the Guest workspace.
  // Re-read profile and routing state after the verified startup identity
  // selects its workspace, otherwise cached Guest data can leak into routing.
  ref.invalidate(appRouteProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(progressSummaryProvider);
  ref.invalidate(qazaRepositoryProvider);
  ref.invalidate(qazaAdditionRepositoryProvider);
  ref.invalidate(qazaPlanRevisionRepositoryProvider);
});

final cloudSyncProvider = Provider<CloudSyncProvider>(
  (ref) => const UnsupportedCloudSyncProvider(),
);

/// Prefix for assets/fonts owned by this package when embedded as a dependency.
/// Null in the standalone offline app; the optional host sets `qaza_namaz`.
final packageAssetNamespaceProvider = Provider<String?>((ref) => null);

final accountLocalStoreProvider = Provider<AccountLocalStore>((ref) {
  final manager = ref.watch(databaseManagerProvider);
  return AccountLocalStore(
    database: manager.controlDatabase,
    databaseManager: manager,
  );
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
    activeUserId: () => ref.read(activeUserIdProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  );
});

final databaseManagerProvider = Provider<DatabaseManager>((ref) {
  final manager = DatabaseManager();
  ref.onDispose(() => unawaited(manager.close()));
  return manager;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseManagerProvider).controlDatabase;
});

final cloudSetupChoiceCompleteProvider = FutureProvider<bool>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  if (await database.isCloudSetupChoiceComplete()) return true;

  // Migration compatibility: installations from before the explicit choice
  // marker existed must not be forced back through first-run account choice.
  // Check durable onboarding metadata directly rather than relying on a routed
  // provider that may be cached while StartupGate itself is initializing.
  if (await database.isOnboardingCompleted()) {
    await database.markCloudSetupChoiceComplete();
    return true;
  }

  final profile = await ref.read(userProfileProvider.future);
  if (profile != null) {
    await database.markCloudSetupChoiceComplete();
    return true;
  }

  return false;
});

/// Durable initial-backup marker, invalidated whenever onboarding or cloud
/// backup completes. It survives process death between local commit and upload.
final initialCloudBackupPendingProvider = FutureProvider<bool>((ref) {
  final localAccountId = ref.watch(activeUserIdProvider);
  return ref.watch(appDatabaseProvider).hasPendingInitialCloudBackup(
        localAccountId: localAccountId,
      );
});

/// Best-effort initial backup retry that never gates local Home navigation.
/// The cloud adapter verifies its own authenticated account before uploading;
/// this additional guard prevents clearing a marker after an account switch.
final initialCloudBackupRetryProvider = FutureProvider<void>((ref) async {
  final sync = ref.watch(cloudSyncProvider);
  if (!sync.isSupported || !ref.watch(cloudAccountProvider).isSupported) return;
  if (ref.watch(skipPendingInitialCloudBackupForSessionProvider)) return;

  final database = ref.watch(appDatabaseProvider);
  final localAccountId = ref.watch(activeUserIdProvider);
  if (localAccountId == null || !localAccountId.startsWith('google:')) return;

  UserProfile? profile;
  try {
    // Depend on the active profile, not just its value at startup, so a
    // workspace that completes onboarding later gets another safe retry.
    profile = await ref.watch(userProfileProvider.future);
  } catch (_) {
    return;
  }
  if (profile?.isComplete != true ||
      ref.watch(activeUserIdProvider) != localAccountId ||
      ref.watch(skipPendingInitialCloudBackupForSessionProvider)) {
    return;
  }
  if (!await database.hasPendingInitialCloudBackup(
    localAccountId: localAccountId,
  )) {
    return;
  }

  try {
    final result = await sync.backupNow();
    if (ref.read(activeUserIdProvider) != localAccountId) return;
    if (result.status == CloudSyncStatus.synced && !result.hasPendingChanges) {
      await database.clearPendingInitialCloudBackup(
        localAccountId: localAccountId,
      );
      ref.invalidate(initialCloudBackupPendingProvider);
    }
  } catch (_) {
    // A failed background attempt leaves all local data and the marker intact.
  }
});

/// Explicit sign-out returns to account choice without resetting onboarding.
final returningAccountChoicePendingProvider = FutureProvider<bool>((ref) {
  return ref.watch(appDatabaseProvider).hasReturningAccountChoicePending();
});

/// Incremented after a successful Qaza completion when cloud is available but
/// no Google account is currently connected.
final guestConnectPromptRequestProvider = StateProvider<int>((ref) => 0);

/// Lets the user continue to Home after an initial backup failure in the
/// current process while retaining the durable marker for a retry next launch.
final skipPendingInitialCloudBackupForSessionProvider =
    StateProvider<bool>((ref) => false);

final qazaLocalStoreProvider = Provider<QazaLocalStore>((ref) {
  final localAccountId = ref.watch(activeUserIdProvider);
  if (localAccountId == null || localAccountId.isEmpty) {
    throw StateError('No active local workspace is ready for Qaza data access.');
  }
  final manager = ref.watch(databaseManagerProvider);
  return DriftQazaLocalStore(
    database: manager.databaseForActiveWorkspace(localAccountId),
  );
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

final qazaAdditionRepositoryProvider = Provider<QazaAdditionRepository>((ref) {
  final localAccountId = ref.watch(activeUserIdProvider);
  if (localAccountId == null || localAccountId.isEmpty) {
    throw StateError('No active local workspace is ready for Qaza additions.');
  }
  final manager = ref.watch(databaseManagerProvider);
  return DriftQazaAdditionRepository(
    manager.databaseForActiveWorkspace(localAccountId),
  );
});

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

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  final manager = ref.watch(databaseManagerProvider);
  return LocalBackupService(
    manager.controlDatabase,
    databaseManager: manager,
  );
});

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
  bool _selectionMade = false;

  @override
  AppThemeMode build() {
    Future<void>.microtask(restore);
    return ref.read(initialThemeModeProvider);
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (_selectionMade || stored == null) return;
      state = AppThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => AppThemeMode.system,
      );
    } catch (_) {
      // Theme preference failures must not block startup.
    }
  }

  void set(AppThemeMode mode) {
    _selectionMade = true;
    state = mode;
    _persist(mode);
  }

  Future<void> _persist(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (_) {
      // Retain the current in-memory selection if persistence is unavailable.
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

class PrimaryColorNotifier extends Notifier<AppPrimaryColor> {
  static const String storageKey = 'qaza_primary_color';
  bool _selectionMade = false;

  @override
  AppPrimaryColor build() {
    Future<void>.microtask(restore);
    return ref.read(initialPrimaryColorProvider);
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (_selectionMade || stored == null) return;
      state = AppPrimaryColor.values.firstWhere(
        (color) => color.name == stored,
        orElse: () => AppPrimaryColor.teal,
      );
    } catch (_) {
      // Theme preference failures must not block startup.
    }
  }

  void set(AppPrimaryColor color) {
    _selectionMade = true;
    state = color;
    _persist(color);
  }

  Future<void> _persist(AppPrimaryColor color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, color.name);
    } catch (_) {
      // Retain the current in-memory selection if persistence is unavailable.
    }
  }
}

final primaryColorProvider =
    NotifierProvider<PrimaryColorNotifier, AppPrimaryColor>(
  PrimaryColorNotifier.new,
);

/// Persists the app-wide Hijri display offset without changing source dates.
final hijriDateAdjustmentProvider =
    AsyncNotifierProvider<HijriDateAdjustmentNotifier, int>(
  HijriDateAdjustmentNotifier.new,
);

class HijriDateAdjustmentNotifier extends AsyncNotifier<int> {
  static const storageKey = 'hijri_date_offset_days';
  static const supportedOffsets = <int>[-2, -1, 0, 1, 2];

  @override
  Future<int> build() async {
    final preferences = await SharedPreferences.getInstance();
    final storedOffset = preferences.getInt(storageKey) ?? 0;
    return supportedOffsets.contains(storedOffset) ? storedOffset : 0;
  }

  Future<void> setOffset(int offsetDays) async {
    if (!supportedOffsets.contains(offsetDays)) {
      throw ArgumentError.value(
        offsetDays,
        'offsetDays',
        'Hijri date offset must be between -2 and +2 days.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(storageKey, offsetDays);
    if (!saved) {
      throw StateError('The Hijri date adjustment could not be saved.');
    }

    state = AsyncData(offsetDays);
  }
}

class LocaleNotifier extends Notifier<Locale> {
  static const String storageKey = 'language_code';
  static const Locale fallback = Locale('en');

  @override
  Locale build() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final resolved = resolve(localeKey(systemLocale)) ??
        resolve(systemLocale.languageCode) ??
        fallback;
    intl.Intl.defaultLocale = localeKey(resolved);
    return resolved;
  }

  static List<Locale> get supported => AppLocalizations.supportedLocales;

  /// Stable persisted identifier; script-sensitive locales use `ur_Latn`.
  static String localeKey(Locale locale) {
    final scriptCode = locale.scriptCode;
    if (scriptCode == null || scriptCode.isEmpty) return locale.languageCode;
    return '${locale.languageCode}_$scriptCode';
  }

  /// Resolves script-specific identifiers and preserves legacy language codes.
  static Locale? resolve(String? localeCode) {
    if (localeCode == null || localeCode.trim().isEmpty) return null;
    final normalized = localeCode.trim().replaceAll('-', '_').toLowerCase();
    for (final locale in supported) {
      if (localeKey(locale).toLowerCase() == normalized) return locale;
    }
    // A legacy 'ur' preference means Urdu Nastaleeq, not Roman Urdu.
    for (final locale in supported) {
      if (locale.languageCode.toLowerCase() == normalized &&
          locale.scriptCode == null) {
        return locale;
      }
    }
    return null;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolved = resolve(prefs.getString(storageKey));
      if (resolved != null) {
        state = resolved;
        intl.Intl.defaultLocale = localeKey(resolved);
      }
    } catch (_) {}
  }

  void preview(Locale locale) {
    final resolved = resolve(localeKey(locale));
    if (resolved == null) return;
    state = resolved;
    intl.Intl.defaultLocale = localeKey(resolved);
  }

  /// Persists a selected locale without changing the currently previewed UI.
  ///
  /// This lets the initial screen serialize preference writes without an
  /// older queued write briefly reverting a newer language selection.
  Future<void> persist(Locale locale) async {
    final resolved = resolve(localeKey(locale));
    if (resolved == null) return;
    await _persist(resolved);
  }

  Future<void> set(Locale locale) async {
    final resolved = resolve(localeKey(locale));
    if (resolved == null) return;
    state = resolved;
    intl.Intl.defaultLocale = localeKey(resolved);
    await _persist(resolved);
  }

  Future<void> _persist(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(storageKey, localeKey(locale));
    if (!saved) {
      throw StateError('The selected language could not be saved.');
    }
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// StartupGate awaits this before rendering interactive onboarding or account
/// choice, avoiding a transient system-locale screen on a saved-language launch.
final localeRestorationProvider = FutureProvider<void>((ref) async {
  await ref.read(localeProvider.notifier).restore();
});
