// Centralized application state.
//
// Composition root for the Qaza Namaz app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../data/auth/firebase_auth_repository.dart';
import '../data/data_transfer/qaza_data_transfer_service.dart';
import '../data/local/database/app_database.dart';
import '../data/local/drift_qaza_local_store.dart';
import '../data/local/qaza_local_store.dart';
import '../data/repositories/firestore_qaza_repository.dart';
import '../data/repositories/offline_first_qaza_repository.dart';
import '../data/sync/sync_state.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/qaza_progress.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../domain/services/qaza_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final qazaLocalStoreProvider = Provider<QazaLocalStore>((ref) {
  return DriftQazaLocalStore(database: ref.watch(appDatabaseProvider));
});

final connectivityChangesProvider = Provider<Stream<bool>>((ref) => Connectivity().onConnectivityChanged.map((results) => results.any((r) => r != ConnectivityResult.none)));
final remoteQazaRepositoryProvider = Provider<QazaRepository>((ref) => FirestoreQazaRepository(firestore: ref.watch(firestoreProvider)));

final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final repository = OfflineFirstQazaRepository(remote: ref.watch(remoteQazaRepositoryProvider), localStore: ref.watch(qazaLocalStoreProvider), connectivityChanges: ref.watch(connectivityChangesProvider));
  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) => repository.setActiveUser(next.valueOrNull?.id), fireImmediately: true);
  ref.onDispose(repository.dispose);
  return repository;
});

final qazaServiceProvider = Provider<QazaService>((ref) => QazaService(ref.watch(qazaRepositoryProvider)));
final qazaDataTransferServiceProvider = Provider<QazaDataTransferService>((ref) => QazaDataTransferService(ref.watch(qazaRepositoryProvider)));
final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authStateProvider).valueOrNull);
final activeUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);
final requiredUserIdProvider = Provider<String>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) throw StateError('This action requires a signed-in account.');
  return userId;
});

class QazaRecordsNotifier extends AsyncNotifier<List<QazaRecord>> {
  @override
  Future<List<QazaRecord>> build() {
    final userId = ref.watch(activeUserIdProvider);
    if (userId == null) return Future.value(const <QazaRecord>[]);
    return ref.watch(qazaServiceProvider).getRecords(userId: userId);
  }

  Future<void> refresh() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      state = const AsyncData(<QazaRecord>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(qazaServiceProvider).getRecords(userId: userId));
  }
}

final qazaRecordsProvider = AsyncNotifierProvider<QazaRecordsNotifier, List<QazaRecord>>(QazaRecordsNotifier.new);
final loadedRecordsProvider = Provider<List<QazaRecord>>((ref) => ref.watch(qazaRecordsProvider).valueOrNull ?? const <QazaRecord>[]);

/// Legacy full-ledger derived providers remain available for detailed/legacy
/// screens, but scalable summary screens must use [progressSummaryProvider].
final overallProgressProvider = Provider<QazaProgress>((ref) => QazaService.progressOf(ref.watch(loadedRecordsProvider)));
final prayerProgressProvider = Provider<Map<PrayerType, PrayerProgress>>((ref) {
  final records = ref.watch(loadedRecordsProvider);
  return {
    for (final prayer in PrayerType.values)
      prayer: PrayerProgress(
        prayerType: prayer,
        progress: QazaService.progressOf(records.where((record) => record.prayerType == prayer)),
      ),
  };
});
final qazaHistoryProvider = Provider<List<QazaRecord>>((ref) => QazaService.completedNewestFirst(ref.watch(loadedRecordsProvider)));
final pendingForPrayerProvider = Provider.family<List<QazaRecord>, PrayerType>((ref, prayer) {
  final pending = ref.watch(loadedRecordsProvider).where((record) => record.prayerType == prayer && record.status == QazaStatus.pending).toList()..sort((a, b) => a.originalDate.compareTo(b.originalDate));
  return pending;
});

/// Database-backed aggregate for Home and other summary screens.
final progressSummaryProvider = FutureProvider.autoDispose<QazaProgressSummary>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(QazaProgressSummary.empty());
  return ref.read(qazaServiceProvider).getProgressSummary(userId: userId);
});

/// Bounded lookup for completion UI. This fetches one record directly from
/// Drift instead of materializing the user's entire pending ledger.
final oldestPendingProvider = FutureProvider.autoDispose.family<QazaRecord?, PrayerType>((ref, prayer) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref.read(qazaServiceProvider).oldestPending(userId: userId, prayerType: prayer);
});

final historyProgressProvider = progressSummaryProvider;

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;
  void set(AppThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);
final offlineRepositoryProvider = Provider<OfflineFirstQazaRepository?>((ref) {
  final repository = ref.watch(qazaRepositoryProvider);
  return repository is OfflineFirstQazaRepository ? repository : null;
});
final syncStateProvider = StreamProvider<SyncState?>((ref) {
  final repository = ref.watch(offlineRepositoryProvider);
  if (repository == null) return const Stream<SyncState?>.empty();
  return repository.syncState.map<SyncState?>((state) => state);
});
