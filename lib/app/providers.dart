// Centralized application state.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/prayer_types.dart';
import '../core/theme/app_theme.dart';
import '../data/auth/firebase_auth_repository.dart';
import '../data/data_transfer/qaza_data_transfer_service.dart';
import '../data/local/qaza_local_store.dart';
import '../data/local/sqlite_qaza_local_store.dart';
import '../data/repositories/firestore_qaza_repository.dart';
import '../data/repositories/paginated_offline_first_qaza_repository.dart';
import '../data/sync/sync_state.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/qaza_ledger_summary.dart';
import '../domain/entities/qaza_record.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/qaza_repository.dart';
import '../domain/services/qaza_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());
final qazaLocalStoreProvider = Provider<QazaLocalStore>((ref) => SqliteQazaLocalStore());
final connectivityChangesProvider = Provider<Stream<bool>>((ref) => Connectivity().onConnectivityChanged.map((results) => results.any((r) => r != ConnectivityResult.none)));
final remoteQazaRepositoryProvider = Provider<QazaRepository>((ref) => FirestoreQazaRepository(firestore: ref.watch(firestoreProvider)));

final qazaRepositoryProvider = Provider<QazaRepository>((ref) {
  final localStore = ref.watch(qazaLocalStoreProvider);
  final repository = PaginatedOfflineFirstQazaRepository(remote: ref.watch(remoteQazaRepositoryProvider), localStore: localStore, connectivityChanges: ref.watch(connectivityChangesProvider));
  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) => repository.setActiveUser(next.valueOrNull?.id), fireImmediately: true);
  ref.onDispose(repository.close);
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
    if (userId == null) { state = const AsyncData(<QazaRecord>[]); return; }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(qazaServiceProvider).getRecords(userId: userId));
  }

  Future<bool> completeOldestPending(PrayerType prayerType) async {
    final userId = ref.read(activeUserIdProvider);
    final records = state.valueOrNull;
    if (userId == null || records == null) return false;
    final pending = records.where((r) => r.prayerType == prayerType && r.status == QazaStatus.pending).toList()..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    if (pending.isEmpty) return false;
    final target = pending.first;
    final completedAt = DateTime.now();
    await ref.read(qazaServiceProvider).completeRecord(userId: userId, recordId: target.id, completedAt: completedAt);
    final latest = state.valueOrNull;
    if (latest != null) {
      state = AsyncData([for (final record in latest) if (record.id == target.id) record.copyWith(status: QazaStatus.completed, completedAt: completedAt, updatedAt: completedAt) else record]);
    }
    return true;
  }
}

final qazaRecordsProvider = AsyncNotifierProvider<QazaRecordsNotifier, List<QazaRecord>>(QazaRecordsNotifier.new);
final loadedRecordsProvider = Provider<List<QazaRecord>>((ref) => ref.watch(qazaRecordsProvider).valueOrNull ?? const <QazaRecord>[]);
final overallProgressProvider = Provider<QazaProgress>((ref) => QazaService.progressOf(ref.watch(loadedRecordsProvider)));
final prayerProgressProvider = Provider<Map<PrayerType, PrayerProgress>>((ref) {
  final records = ref.watch(loadedRecordsProvider);
  return {for (final prayer in PrayerType.values) prayer: PrayerProgress(prayerType: prayer, progress: QazaService.progressOf(records.where((record) => record.prayerType == prayer)))};
});
final qazaLedgerSummaryProvider = FutureProvider.autoDispose<QazaLedgerSummary>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return Future.value(const QazaLedgerSummary());
  return ref.watch(qazaRepositoryProvider).getSummary(userId);
});
final qazaHistoryProvider = Provider<List<QazaRecord>>((ref) => QazaService.completedNewestFirst(ref.watch(loadedRecordsProvider)));
final pendingForPrayerProvider = Provider.family<List<QazaRecord>, PrayerType>((ref, prayer) => ref.watch(loadedRecordsProvider).where((r) => r.prayerType == prayer && r.status == QazaStatus.pending).toList()..sort((a, b) => a.originalDate.compareTo(b.originalDate)));

class ThemeModeNotifier extends Notifier<AppThemeMode> { @override AppThemeMode build() => AppThemeMode.system; void set(AppThemeMode mode) => state = mode; }
final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);
final offlineRepositoryProvider = Provider<OfflineFirstQazaRepository?>((ref) { final repository = ref.watch(qazaRepositoryProvider); return repository is OfflineFirstQazaRepository ? repository : null; });
final syncStateProvider = StreamProvider<SyncState?>((ref) { final repository = ref.watch(offlineRepositoryProvider); if (repository == null) return const Stream<SyncState?>.empty(); return repository.syncState.map<SyncState?>((state) => state); });
