// Centralized application state.
//
// Composition root for the Qaza Namaz app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../data/sync/sync_state.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../features/auth/guest_session.dart';
import '../domain/services/qaza_service.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => FirebaseAuthRepository());

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
final remoteQazaRepositoryProvider = Provider<QazaRepository>(
    (ref) => FirestoreQazaRepository(firestore: ref.watch(firestoreProvider)));

final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final repository = OfflineFirstQazaRepository(
      remote: ref.watch(remoteQazaRepositoryProvider),
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

final qazaServiceProvider = Provider<QazaService>(
    (ref) => QazaService(ref.watch(qazaRepositoryProvider)));
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
/// Everything downstream — the repository, the aggregates, notification
/// preferences — is scoped by this, so guest data is isolated by the same
/// mechanism that isolates one account from another.
final activeUserIdProvider = Provider<String?>((ref) {
  // During an in-progress guest upgrade Firebase may already expose the
  // account UID. Keep all normal app reads on the guest ledger until the
  // explicit merge/account/cancel decision has completed.
  if (ref.watch(guestUpgradePendingProvider)) return guestUserId;

  final signedIn = ref.watch(currentUserProvider)?.id;
  if (signedIn != null) return signedIn;
  return ref.watch(isGuestProvider) ? guestUserId : null;
});
final requiredUserIdProvider = Provider<String>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    throw StateError('This action requires a signed-in account.');
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
