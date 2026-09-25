// Centralized application state.
//
// Composition root for the Qaza Namaz app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../data/auth/firebase_auth_repository.dart';
import '../data/data_transfer/qaza_data_transfer_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/drift_qaza_local_store.dart';
import '../data/local/qaza_local_store.dart';
import '../data/repositories/firestore_qaza_repository.dart';
import '../data/repositories/offline_first_qaza_repository.dart';
import '../data/sync/qaza_sync_remote_data_source.dart';
import '../data/sync/sync_state.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../features/auth/guest_session.dart';
import '../domain/services/qaza_service.dart';
import '../domain/services/sahib_al_tartib_service.dart';
import '../domain/services/qaza_undo_service.dart';
import '../domain/services/qaza_operation_service.dart';
import '../domain/repositories/qaza_operation_repository.dart';
import '../data/repositories/shared_preferences_qaza_operation_repository.dart';
import '../domain/services/cloud_data_deletion_service.dart';
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
  // The startup gate never enters the workspace before a complete profile is
  // loaded. The fallback keeps legacy/test containers deterministic.
  return profile == null ? true : ProfileRules.effectiveWitr(profile);
});

final qazaPlanServiceProvider = Provider<QazaPlanService>(
  (ref) => const QazaPlanService(),
);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firestoreQazaRepositoryProvider = Provider<FirestoreQazaRepository>(
  (ref) => FirestoreQazaRepository(firestore: ref.watch(firestoreProvider)),
);
final remoteQazaRepositoryProvider = Provider<QazaRepository>(
  (ref) => ref.watch(firestoreQazaRepositoryProvider),
);
final remoteQazaSyncDataSourceProvider = Provider<QazaSyncRemoteDataSource>(
  (ref) => ref.watch(firestoreQazaRepositoryProvider),
);
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => FirebaseAuthRepository(
          diagnostics: ref.watch(diagnosticsProvider),
        ));

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final qazaLocalStoreProvider = Provider<QazaLocalStore>((ref) {
  return DriftQazaLocalStore(database: ref.watch(appDatabaseProvider));
});

final connectivityChangesProvider = Provider<Stream<bool>>((ref) =>
    Connectivity()
        .onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none)));

final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final repository = OfflineFirstQazaRepository(
      diagnostics: ref.watch(diagnosticsProvider),
      remote: ref.watch(remoteQazaRepositoryProvider),
      syncRemote: ref.watch(remoteQazaSyncDataSourceProvider),
      localStore: ref.watch(qazaLocalStoreProvider),
      connectivityChanges: ref.watch(connectivityChangesProvider));
  // Follows the active ledger rather than the account directly, so a guest
  // session opens their local records the same way an account opens theirs.
  ref.listen<String?>(
      activeUserIdProvider, (_, next) => repository.setActiveUser(next),
      fireImmediately: true);
  ref.onDispose(repository.dispose);
  return repository;
});

/// Where failures are reported.
///
/// Debug output by default. A crash-reporting backend is added by overriding
/// this provider with a `FanOutDiagnostics([const DebugDiagnostics(), ...])`,
/// which is the only change the rest of the app needs.
final diagnosticsProvider = Provider<DiagnosticsService>(
  (ref) => kReleaseMode
      ? PersistentDiagnostics()
      : const DebugDiagnostics(),
);

final qazaServiceProvider = Provider<QazaService>((ref) => QazaService(
      ref.watch(qazaRepositoryProvider),
      witrInclusionResolver: () => ref.read(effectiveWitrProvider),
      diagnostics: ref.watch(diagnosticsProvider),
    ));

/** The current user's Sahib al-Tartib state. */
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
    (ref) => QazaDataTransferService(ref.watch(qazaRepositoryProvider)));
final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());
final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authStateProvider).valueOrNull);

/// True while the app is being used without an account.
///
/// A signed-in account always wins: signing in ends guest mode, and this
/// reports the account from that moment on.
final isGuestProvider = Provider<bool>((ref) =>
    ref.watch(currentUserProvider) == null && ref.watch(guestSessionProvider));

/// Whose ledger is on screen: an account id, the reserved guest id, or none.
///
/// Everything downstream — the repository and aggregates — is scoped by
/// this, so guest data is isolated by the same
/// mechanism that isolates one account from another.
final activeUserIdProvider = Provider<String?>((ref) {
  // During an in-progress guest-to-account decision, Firebase may already
  // expose the account UID. Keep reads on the guest ledger until the user
  // explicitly chooses merge, account-only, or cancel.
  if (ref.watch(guestUpgradePendingProvider)) return guestUserId;

  final signedIn = ref.watch(currentUserProvider)?.id;
  if (signedIn != null) return signedIn;

  // A completed local profile owns the local ledger. It is deliberately not
  // presented as "Guest Mode" anywhere in the product.
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile != null) return UserProfile.localLedgerUserId;

  return ref.watch(isGuestProvider) ? guestUserId : null;
});
final requiredUserIdProvider = Provider<String>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    throw StateError('A completed local profile is required.');
  }
  return userId;
});

/// Database-backed aggregate for Home and other summary screens.
final progressSummaryProvider =
    FutureProvider.autoDispose<QazaProgressSummary>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(QazaProgressSummary.empty());
  return ref.read(qazaServiceProvider).getProgressSummary(userId: userId);
});

/// Bounded lookup for completion UI. This fetches one record directly from
/// Drift instead of materializing the user's entire pending ledger.
final oldestPendingProvider =
    FutureProvider.autoDispose.family<QazaRecord?, PrayerType>((ref, prayer) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref
      .read(qazaServiceProvider)
      .oldestPending(userId: userId, prayerType: prayer);
});

/// The newest pending record for one prayer, bounded the same way.
final latestPendingProvider =
    FutureProvider.autoDispose.family<QazaRecord?, PrayerType>((ref, prayer) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref
      .read(qazaServiceProvider)
      .latestPending(userId: userId, prayerType: prayer);
});

/// Theme choice, persisted locally and restored on startup.
///
/// The default stays [AppThemeMode.system] until a stored choice loads, so the
/// first frame never flashes the wrong theme.
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
    } catch (_) {
      // A missing or unreadable store simply leaves the system default.
    }
  }

  void set(AppThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  Future<void> _persist(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (_) {
      // Persistence failure must not break the in-session theme change.
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

/// Language choice, persisted locally and restored on startup.
///
/// Only locales in [AppLocalizations.supportedLocales] are accepted, so adding
/// Arabic is a matter of adding `app_ar.arb` — no application restructuring.
/// Text direction is left to Flutter's own `Directionality` for the locale.
class LocaleNotifier extends Notifier<Locale> {
  static const String storageKey = 'qaza_locale';
  static const Locale fallback = Locale('en');

  @override
  Locale build() {
    Future.microtask(restore);
    return fallback;
  }

  /// The locales the application can actually render.
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
    } catch (_) {
      // An unreadable store simply leaves the default language.
    }
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
    } catch (_) {
      // Persistence failure must not break the in-session language change.
    }
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
final offlineRepositoryProvider = Provider<OfflineFirstQazaRepository?>((ref) {
  final repository = ref.watch(qazaRepositoryProvider);
  return repository is OfflineFirstQazaRepository ? repository : null;
});
final syncStateProvider = StreamProvider<SyncState?>((ref) {
  final repository = ref.watch(offlineRepositoryProvider);
  if (repository == null) return const Stream<SyncState?>.empty();
  return repository.syncState.map<SyncState?>((state) => state);
});

final cloudDataDeletionServiceProvider =
    Provider<CloudDataDeletionService>((ref) {
  return CloudDataDeletionService(
    remote: ref.watch(remoteQazaSyncDataSourceProvider),
    localStore: ref.watch(qazaLocalStoreProvider),
    syncBeforeDelete: ref.watch(offlineRepositoryProvider)?.syncNow,
  );
});

final cloudDataDeletedAtProvider =
    FutureProvider.autoDispose.family<DateTime?, String>((ref, userId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('qaza_cloud_deleted_at_$userId');
  return raw == null ? null : DateTime.tryParse(raw);
});