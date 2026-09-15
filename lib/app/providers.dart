// Centralized application state.
//
// Composition root for the Qaza Namaz app. Screens read what they need from
// these providers instead of receiving repositories, services and user ids
// through widget constructors, so swapping an implementation (Firestore vs. an
// in-memory double, a fixed clock, a different user) is a single override in
// one place.
//
// Layering, outermost first:
//   1. Infrastructure : Firebase handles, auth, local cache, connectivity.
//   2. Repositories   : offline-first Qaza store wrapped around Firestore.
//   3. Domain         : QazaService and the shared calendar engine.
//   4. Session        : signed-in account and active Firebase UID.
//   5. Derived views  : records, progress and history for the active account.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../data/auth/firebase_auth_repository.dart';
import '../data/local/qaza_local_store.dart';
import '../data/local/shared_preferences_qaza_local_store.dart';
import '../data/repositories/firestore_qaza_repository.dart';
import '../data/repositories/offline_first_qaza_repository.dart';
import '../data/sync/sync_state.dart';
import '../domain/calendar/calendar_engine.dart';
import '../domain/entities/app_user.dart';

import '../domain/entities/qaza_record.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../domain/services/qaza_service.dart';

// ---------------------------------------------------------------------------
// 1. Infrastructure
// ---------------------------------------------------------------------------

/// Cloud Firestore handle used by the remote Qaza store.
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Authentication backend (Firebase Auth + Google Sign-In).
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => FirebaseAuthRepository());

/// Local offline cache, namespaced per Firebase UID.
final qazaLocalStoreProvider =
    Provider<QazaLocalStore>((ref) => SharedPreferencesQazaLocalStore());

/// Device connectivity mapped to a simple "is online" stream. The offline-first
/// repository flushes its outbox as soon as this emits `true`.
final connectivityChangesProvider = Provider<Stream<bool>>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

// ---------------------------------------------------------------------------
// 2. Repositories
// ---------------------------------------------------------------------------

/// The authoritative remote store. Isolated so tests can substitute it without
/// going through the offline layer.
final remoteQazaRepositoryProvider =
    Provider<QazaRepository>((ref) => FirestoreQazaRepository(
          firestore: ref.watch(firestoreProvider),
        ));

/// The repository every screen reads and writes through: local cache first,
/// background sync to Firestore second.
///
/// The offline cache is namespaced per Firebase UID, and keeping that namespace
/// in step with the signed-in account lives here rather than in a widget, so
/// sign-in, account switch and sign-out all funnel through one listener.
final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final repository = OfflineFirstQazaRepository(
    remote: ref.watch(remoteQazaRepositoryProvider),
    localStore: ref.watch(qazaLocalStoreProvider),
    connectivityChanges: ref.watch(connectivityChangesProvider),
  );

  ref.listen<AsyncValue<AppUser?>>(
    authStateProvider,
    (_, next) => repository.setActiveUser(next.valueOrNull?.id),
    fireImmediately: true,
  );

  ref.onDispose(repository.dispose);
  return repository;
});

// ---------------------------------------------------------------------------
// 3. Domain services
// ---------------------------------------------------------------------------

/// Business operations over the Qaza ledger.
final qazaServiceProvider = Provider<QazaService>(
  (ref) => QazaService(ref.watch(qazaRepositoryProvider)),
);

/// Gregorian/Hijri calendar engine shared by every date-aware screen so date
/// rules are never re-implemented per widget.
final calendarEngineProvider = Provider<CalendarEngine>(
  (ref) => CalendarEngine(),
);

// ---------------------------------------------------------------------------
// 4. Session
// ---------------------------------------------------------------------------

/// Signed-in account, or `null` when signed out.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The current user without the [AsyncValue] wrapper.
final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authStateProvider).valueOrNull);

/// Firebase UID of the active account; `null` when signed out.
final activeUserIdProvider =
    Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);

/// The active UID for action handlers that can only run while signed in.
///
/// Only ever `read` (never `watch`ed), so a signed-out frame cannot throw
/// during build.
final requiredUserIdProvider = Provider<String>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) {
    throw StateError('This action requires a signed-in account.');
  }
  return userId;
});

// ---------------------------------------------------------------------------
// 5. Derived ledger views
// ---------------------------------------------------------------------------

/// Every Qaza record for the active account.
///
/// A single provider owns the ledger, so Dashboard, Logs and the completion
/// flows share one read instead of each fetching on init, and moving between
/// tabs never re-queries. It rebuilds only when the active account changes or
/// when [refresh] is called after a write.
class QazaRecordsNotifier extends AsyncNotifier<List<QazaRecord>> {
  @override
  Future<List<QazaRecord>> build() {
    final userId = ref.watch(activeUserIdProvider);
    if (userId == null) return Future.value(const <QazaRecord>[]);
    return ref.watch(qazaServiceProvider).getRecords(userId: userId);
  }

  /// Re-reads the ledger, e.g. for pull-to-refresh or after a write.
  Future<void> refresh() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      state = const AsyncData(<QazaRecord>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(qazaServiceProvider).getRecords(userId: userId),
    );
  }
}

final qazaRecordsProvider =
    AsyncNotifierProvider<QazaRecordsNotifier, List<QazaRecord>>(
  QazaRecordsNotifier.new,
);

/// The loaded ledger, or an empty list while loading/errored. Keeps the derived
/// views below synchronous and cheap.
final loadedRecordsProvider = Provider<List<QazaRecord>>(
  (ref) => ref.watch(qazaRecordsProvider).valueOrNull ?? const <QazaRecord>[],
);

/// Pending/completed totals across all six prayers.
final overallProgressProvider = Provider<QazaProgress>(
  (ref) => QazaService.progressOf(ref.watch(loadedRecordsProvider)),
);

/// Per-prayer progress for all six prayers, derived from the same in-memory
/// ledger so no screen triggers an extra read.
final prayerProgressProvider = Provider<Map<PrayerType, PrayerProgress>>((ref) {
  final records = ref.watch(loadedRecordsProvider);
  return {
    for (final prayer in PrayerType.values)
      prayer: PrayerProgress(
        prayerType: prayer,
        progress: QazaService.progressOf(
          records.where((record) => record.prayerType == prayer),
        ),
      ),
  };
});

/// Completed records, newest completion first.
final qazaHistoryProvider = Provider<List<QazaRecord>>(
  (ref) => QazaService.completedNewestFirst(ref.watch(loadedRecordsProvider)),
);

/// Pending records for one prayer, oldest first — the order Qaza is completed
/// in.
final pendingForPrayerProvider =
    Provider.family<List<QazaRecord>, PrayerType>((ref, prayer) {
  final pending = ref
      .watch(loadedRecordsProvider)
      .where((record) =>
          record.prayerType == prayer && record.status == QazaStatus.pending)
      .toList()
    ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
  return pending;
});

// ---------------------------------------------------------------------------
// 6. Theme & synchronization
// ---------------------------------------------------------------------------

/// Active application theme mode (System / Light / Dark).
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  /// Applies [mode] to the whole application.
  void set(AppThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

/// The active repository when it has an offline layer, else `null`.
///
/// Keeping this decision in a provider lets every sync surface stay inert for
/// the in-memory doubles used in tests without a single `is` check per widget.
final offlineRepositoryProvider = Provider<OfflineFirstQazaRepository?>((ref) {
  final repository = ref.watch(qazaRepositoryProvider);
  return repository is OfflineFirstQazaRepository ? repository : null;
});

/// Live sync-layer snapshot for the active account.
///
/// Emits nothing while no offline layer is active ([offlineRepositoryProvider]
/// is `null`), so the sync surfaces render nothing at all in that case.
final syncStateProvider = StreamProvider<SyncState?>((ref) {
  final repository = ref.watch(offlineRepositoryProvider);
  if (repository == null) return const Stream<SyncState?>.empty();
  return repository.syncState.map<SyncState?>((state) => state);
});